local image = {
  rt_index = 0,
  rts = setmetatable({}, {__mode = "k"}),
  rt_mat = setmetatable({}, {__mode = "k"})
}

local ImageDataIndex = {}
function ImageDataIndex:GetDimensions()
    return self:getWidth(), self:getHeight()
end
function ImageDataIndex:getHeight()
    return self.rh
end
function ImageDataIndex:getWidth()
    return self.rw
end


function ImageDataIndex:getPixel(x, y)
    if (not self.original_png) then
      return 0, 0, 0, 255
    end
    local rw = self.rw
    local index = x + y * rw
    local col = self.cache_getpixel[index]
    if (not col) then
      col = {nil, nil, nil, nil, 1}
      local real = self.original_png:GetColor(x, y)
      col[1], col[2], col[3], col[4] = real.r, real.g, real.b, real.a
      self.cache_getpixel[index] = col
    end
    return col[1], col[2], col[3], col[4]
end

local colors = {n=0}

local function load_color(r,g,b,a)
  local n = colors.n
  if (n == 0) then
    return {r, g, b, a, 1}
  end
  local col = colors[n]
  colors[n] = nil
  colors.n = n - 1
  col[1], col[2], col[3], col[4] = r, g, b, a or 255
  return col
end
local function free_color(c)
  local n = colors.n + 1
  colors[n] = c
  colors.n = n
end

function ImageDataIndex:setPixel(x, y, r, g, b, a)
  local colors = self.colors
  local col = r + g * 256 + b * 256*256 + (a or 255) * 256*256*256
  if (not colors[col]) then
    colors[col] = {n=0}
    local n = self.list.n + 1
    self.list[n] = col
    self.list.n = n
  end
  local coltbl = colors[col]
  local n = coltbl.n + 1
  coltbl[n] = x + y * self.rw
  coltbl.n = n
  self.num_updated = self.num_updated + 1
end

local color = Material "color"
local v = Vector()
local col_lookup = {}

function ImageDataIndex:refresh()
  local set_pixels = self.pixels
  local list = self.list
  local colors = self.colors
  local col_lookup = col_lookup
  local v_lookup = self.v_lookup
  local rw = self.rw

  local mesh_AdvanceVertex = mesh.AdvanceVertex
  local mesh_Position = mesh.Position
  local mesh_Color = mesh.Color

  render.PushRenderTarget(self.gmdata)
    cam.Start2D()
      render.SetColorMaterial()
      mesh.Begin(MATERIAL_POINTS, self.num_updated)
        for i = list.n, 1, -1 do
          local col = list[i]
          if (not col_lookup[col]) then
            local colr = col % 0x100
            local colg = col % 0x10000 - colr
            local colb = col % 0x1000000 - colg - colr 
            local cola = col % 0x100000000 - colb - colg - colb
            colg = colg / 0x100
            colb = colb / 0x10000
            cola = cola / 0x1000000
            local new = {colr, colg, colb, cola}
            col_lookup[col] = new
          end
          local pixels = colors[col]
          local real_col = col_lookup[col]

          for i = 1, #pixels do
            local pixel = pixels[i]
              if (set_pixels[pixel] ~= col) then
              if (not v_lookup[pixel]) then
                local x = pixel % rw
                local y = (pixel - x) / rw
                v_lookup[pixel] = Vector(x, y)
              end
              local v = v_lookup[pixel]

              mesh_Color(real_col[1], real_col[2], real_col[3], real_col[4])
              mesh_Position(v)
              mesh_AdvanceVertex()
              set_pixels[pixel] = col
            end
          end
          colors[col] = nil
        end

      mesh.End()
      self.num_updated = 0
      list.n = 0
    cam.End2D()
  render.PopRenderTarget(rt)


end

local ImageDataMT = {
  __index = ImageDataIndex
}

local ImageIndex = {}
function ImageIndex:refresh()
  return self.tex:refresh()
end
local ImageMT = {
  __index = ImageIndex
}

local function WrapImage(mat, tex)
  return setmetatable({
    mat = mat,
    tex = tex
  }, ImageMT)
end

image.__love_wrapimage = WrapImage

local function WrapImageData(texture, rw, rh, original_png)
  return setmetatable({
    cache_getpixel = {},
    list = {n=0},
    num_updated = 0,
    colors = {}, 
    gmdata = texture, 
    rw = rw, 
    rh = rh, 
    fw = texture:GetMappingWidth(), 
    fh = texture:GetMappingHeight(),
    original_png = original_png,
    pixels = {},
    v_lookup = {}
  }, ImageDataMT)
end

local graphics = love.require "graphics"

image.istexture = function(obj)
  return type(obj) == "table" and getmetatable(obj) == ImageDataMT
end
image.ismaterial = function(obj)
  return type(obj) == "table" and getmetatable(obj) == ImageMT
end

local png_count = 0
local rand = tostring(math.random()):gsub("%.","_")

local function wait_png(matstr)
  local html = vgui.Create("DHTML")
  html:AddFunction("console", "memeify", function()
    html.done = true
  end)
  local mat = Material(matstr)
  local rw, rh = mat:GetInt "$realwidth", mat:GetInt "$realheight"

  local f = file.Open("materials/"..matstr, "rb", "GAME")
  local cont = f:Read(f:Size())
  f:Close()
  f = file.Open(matstr:gsub("/","_"), "wb", "DATA")
  f:Write(cont)
  f:Close() 
  html:SetPos(ScrW() - 1, ScrH() - 1)
  local mapw, maph = 1, 1
  while (mapw < rw) do
    mapw = mapw * 2
  end
  while (maph < rh) do
    maph = maph * 2
  end
  html:SetSize(mapw, maph)
  html:SetHTML([[
    <style>
      html { 
        overflow:hidden;
        margin: -8px -8px;
      }
    </style>
    <html>
      <img onload="console.memeify();" src="asset://garrysmod/data/]]..matstr:gsub("/","_")..[[" />
    </html>
  ]])
  html:SetVisible(true)


  local co = love.__love_co
  local transplant = CreateMaterial("LoveEMU_"..rand.."transplant_png_"..png_count..matstr, "UnlitGeneric", {
    ["$translucent"] = 1,
    ["$nolod"] = 1,
    ["$ignorez"] = 1,
    ["$vertexalpha"] = 0,
  })
  png_count = png_count + 1
  love.__love_incallback = true

  local resume = function()
    love.__love_incallback = false
    love.__love_resume(co, transplant, rw, rh, mat)
  end

  hook.Add("Think", "LoveEMU_TransplantPNG", function()
    if (IsValid(html) and html.done and html:GetHTMLMaterial()) then
      local tex = html:GetHTMLMaterial():GetTexture "$basetexture"
      transplant:SetTexture("$basetexture", tex)
      tex:Download()
      html:Remove()

      -- lol fuck memory we can't destroy or reuse it
      local rt = GetRenderTargetEx("LoveEMU_"..rand.."transplant_rt_"..png_count..matstr,  
        mapw, maph, RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE, 1, CREATERENDERTARGETFLAGS_UNFILTERABLE_OK, IMAGE_FORMAT_RGBA8888)
      render.PushRenderTarget(rt)
        render.OverrideAlphaWriteEnable(true, true) 
        cam.Start2D()
          render.Clear(0, 0, 0, 0, false, false)
          surface.SetMaterial(transplant)
          surface.SetDrawColor(255,255,255,255)
          surface.DrawTexturedRectUV(0, 0, rw, rh, 0, 0, rw / mapw, rh / maph)
          render.OverrideAlphaWriteEnable(true, false) 
          file.Write("loveemu_pot_"..matstr:gsub("/","_"), render.Capture {
            format = "png",
            alpha = true,
            x = 0,
            y = 0,
            w = mapw,
            h = maph
          })
        cam.End2D()
        mat = Material("data/loveemu_pot_"..matstr:gsub("/","_"), "noclamp")
      render.PopRenderTarget(rt)
      resume()
    end
  end)

  return love.__love_yield()
end

image.newImageData = function(width_or_name, height)
  if (love.__love_curfunc == "draw") then
    error "unsupported: newImageData in draw function"
  end

  if (type(width_or_name) == "string") then
    local mat, rw, rh, original_png = wait_png("luagb/"..width_or_name)
    assert(not mat:IsError(), "Material doesn't exist")
    local rt = mat:GetTexture "$basetexture"
    assert(not rt:IsError(), "Sanity check - mat:GetTexture '$basetexture' is error")

    rt = WrapImageData(rt, rw, rh, original_png)

    local index = image.rt_index
    image.rts[rt] = index
    image.rt_index = index + 1
    image.rt_mat[rt] = WrapImage(mat, rt)
    return rt
  end

  local index = image.rt_index
  image.rt_index = index + 1
  local mapw, maph = 1, 1

  while (mapw < width_or_name) do
    mapw = mapw * 2
  end
  while (maph < height) do
    maph = maph * 2
  end
  local tex = WrapImageData(GetRenderTargetEx("LuaGBRT_"..rand.."_"..index, mapw, maph, RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE,
    1 + 8388608 + 512 + 256, CREATERENDERTARGETFLAGS_UNFILTERABLE_OK, IMAGE_FORMAT_RGB888), width_or_name, height)
  
  image.rts[tex] = index

  return tex
end

return image