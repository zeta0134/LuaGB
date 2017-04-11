local rand = tostring(math.random()):gsub("%.", "_")
local png_count = 0
local function wait_png(co, matstr)
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

  local transplant = CreateMaterial("LoveEMU_"..rand.."transplant_png_"..png_count..matstr, "UnlitGeneric", {
    ["$translucent"] = 1,
    ["$nolod"] = 1,
    ["$ignorez"] = 1,
    ["$vertexalpha"] = 0,
  })
  png_count = png_count + 1

  hook.Add("Think", "LoveEMU_TransplantPNG", function()
    if (IsValid(html) and html.done and html:GetHTMLMaterial()) then
      local tex = html:GetHTMLMaterial():GetTexture "$basetexture"
      transplant:SetTexture("$basetexture", tex)
      tex:Download()
      html:Remove()
      hook.Remove("Think", "LoveEMU_TransplantPNG")
      coroutine.resume(co, transplant, rw, rh, tex:GetMappingWidth(), tex:GetMappingHeight())
    end
  end)

  return coroutine.yield()
end

local co
co = coroutine.create(function()
    print"get..."
    local transplant, rw, rh, mapw, maph = wait_png(co, "luagb/images/d-pad.png")
    timer.Simple(1, function()
    for x = 0, rw do
        local c = transplant:GetTexture "$basetexture":GetColor(x, 1)
        print(c.r,c.g,c.b,c.a)
    end
    print"got..."hook.Add("HUDPaint","", function()
        surface.SetDrawColor(255,255,255,255)
        surface.SetMaterial(transplant)
        surface.DrawTexturedRect(0,0,mapw, maph) 
    end)
    end)
end)
print(coroutine.resume(co))