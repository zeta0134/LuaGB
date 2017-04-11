local graphics = {}
local love = love

graphics.newImageFont = function(filename, glyphs, spacing)
    
    local img, err = love.image.newImageData(filename)

    if (not img) then
        return img, err
    end

    local mat, err = graphics.newImage(img)

    local fontdata = {
        img = mat,
        spacing = spacing or 0
    }

    local col = Color(img:getPixel(0, 0))

    local utf8glyphs = {}

    for byte, char in utf8.codes(glyphs) do
        utf8glyphs[#utf8glyphs + 1] = char
    end

    local glyphnum = 1
    local lastglyphx = 1
    for x = 1, img:getWidth() - 1 do
        local pixelcol = Color(img:getPixel(x, 0))
        if (pixelcol == col) then
            fontdata[utf8glyphs[glyphnum]] = {lastglyphx, x - 1}
            lastglyphx = x + 1
            glyphnum = glyphnum + 1
            if (glyphnum > #utf8glyphs) then
                break
            end
        end
    end
    assert(glyphnum == #utf8glyphs + 1, "glyphs not complete")

    return fontdata

end

graphics.setFont = function(font)
    graphics.__love_font = font
end

graphics.print = function(text, x, y, r, sx, sy, ox, oy, kx, ky)
    local font = graphics.__love_font
    assert(font, "no font loaded")
    local mat = font.img
    local height = mat:GetTexture "$basetexture":GetMappingHeight()
    local width = mat:GetTexture "$basetexture":GetMappingWidth()
    
    surface.SetColor(0, 0, 0, 0)
    surface.SetMaterial(mat)

    for byte, char in utf8.codes(text) do
        local place = font[char]
        assert(place, "no font data for char")
        if (place[1] ~= place[2]) then
            surface.DrawTexturedRectUV(x, y, place[2] - place[1], height, place[1] / width, 0, place[2] / width, 1)
            x = x + place[2] - place[1]
        end
        x = x + 1 + font.spacing
    end

end

local mat_Draw = CreateMaterial("mat_DrawLOVE2D", "UnlitGeneric", {})


graphics.draw = function(texture, quad, x, y, r, sx, sy, ox, oy, kx, ky)
  if (love.image.istexture(texture)) then
    
    mat_Draw:SetTexture("$basetexture", texture.gmdata)

    graphics.pushDrawColor(color_white)
        surface.SetMaterial(mat_Draw)

        surface.DrawTexturedRect(x, y, texture:getWidth(), texture:getHeight())

    graphics.popDrawColor()
  elseif (love.image.ismaterial(texture)) then

        surface.SetDrawColor(255,255,255,255)
        surface.SetMaterial(texture.mat)
        local tex = texture.tex

        local sw, sh = graphics.__love_scale_width, graphics.__love_scale_height

        surface.DrawTexturedRectUV(quad * sw, x * sh, tex:getWidth() * sw, 
          tex:getHeight() * sh, 0, 0, tex.rw / tex.fw, tex.rh / tex.fh)

    --graphics.popDrawColor()

  else
    error("UNSUPPORTED DRAW CALL: "..type(texture))
  end

end

local rand = tostring(math.random()):gsub("%.","_")

graphics.newImage = function(rt_or_name)
  local rt = rt_or_name
  local image = love.image
  local mat = image.rt_mat[rt]
  if (not mat and type(rt) == "string") then
    rt = image.newImageData(rt)
  end
  mat = image.rt_mat[rt]
  if (not mat) then

    local index = image.rts[rt]
    assert(index, "RenderTarget not made from luagb library")
    mat = image.__love_wrapimage(CreateMaterial("LuaGBMaterial_"..rand..index, "UnlitGeneric", {}), rt)
    mat.mat:SetTexture("$basetexture", rt.gmdata)
    image.rt_mat[rt] = mat
  end
  return mat
end

graphics.setCanvas = function() end
graphics.push = function() end
graphics.pop = function() end

graphics.setColor = function() end

graphics.setDefaultFilter = function() end
graphics.__love_scale_width, graphics.__love_scale_height = 1, 1
graphics.scale = function(width, height)
    graphics.__love_scale_width, graphics.__love_scale_height = width, height
end


return graphics