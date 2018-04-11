local bit32 = require("bit")

local oam = {}

oam.width = 320

oam.init = function(gameboy)
  oam.canvas = love.graphics.newCanvas(160, 400)
  oam.gameboy = gameboy
  oam.sprite_imagedata = love.image.newImageData(8, 16)
  oam.sprite_image = love.graphics.newImage(oam.sprite_imagedata)
  oam.background_8x8_image = love.graphics.newImage("images/debug_oam_8x8_background.png")
  oam.background_8x16_image = love.graphics.newImage("images/debug_oam_8x16_background.png")
end

oam.draw_sprite = function(sprite_address, sx, sy, sprite_size)
  local graphics = oam.gameboy.graphics
  local io = oam.gameboy.io
  local ports = oam.gameboy.io.ports

  local sprite = graphics.cache.oam[(sprite_address - 0xFE00) / 4]
  local sprite_flags = graphics.oam[sprite_address + 3]

  for y = 0, (sprite_size - 1) do
    for x = 0, 7 do
      local color
      if y < 8 then
        if sprite_size == 8 then
          color = sprite.palette[sprite.tile[x][y]]
        else
          color = sprite.palette[sprite.upper_tile[x][y]]
        end
      else
        color = sprite.palette[sprite.lower_tile[x][y - 8]]
      end
      oam.sprite_imagedata:setPixel(sx + x, sy + y, color[1] / 255, color[2] / 255, color[3] / 255, 1)
    end
  end

  return sprite_tile, sprite.x, sprite.y, sprite_flags
end

oam.draw_sprites = function()
  -- Clear out the sprite buffer before we start
  oam.sprite_imagedata:mapPixel(function()
    return 0, 0, 0, 0
  end)

  local cell_width = 40
  local cell_height = 24
  local sprites_per_row = 4
  local sprite_scaling = 2

  local sprite_size = 8
  if oam.gameboy.graphics.registers.large_sprites then
    sprite_size = 16
    sprite_scaling = 1
  end

  love.graphics.setColor(1, 1, 1)
  if sprite_size == 8 then
    love.graphics.draw(oam.background_8x8_image, 0, 0)
  else
    love.graphics.draw(oam.background_8x16_image, 0, 0)
  end

  local x = 0
  local y = 0
  for i = 0, 39 do
    -- draw the sprite
    local tile, sprite_x, sprite_y, flags = oam.draw_sprite(0xFE00 + (i * 4), 0, 0, sprite_size)
    love.graphics.setCanvas(oam.canvas)
    love.graphics.push()
    love.graphics.scale(sprite_scaling, sprite_scaling)
    love.graphics.setColor(1, 1, 1)
    oam.sprite_image:replacePixels(oam.sprite_imagedata)
    love.graphics.draw(oam.sprite_image, ((3 + x * cell_width) / sprite_scaling), ((10 + y * cell_height) / sprite_scaling))
    love.graphics.pop()
    -- draw info about this sprite
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(string.format("X:%02X", bit32.band(sprite_x, 0xFF)), x * cell_width + cell_width - 17, y * cell_height + 9)
    love.graphics.print(string.format("Y:%02X", bit32.band(sprite_y, 0xFF)), x * cell_width + cell_width - 17, y * cell_height + 16)
    love.graphics.print(string.format("F:%02X", flags   ), x * cell_width + cell_width - 17, y * cell_height + 23)
    x = x + 1
    if x >= sprites_per_row then
      x = 0
      y = y + 1
    end
  end
end

oam.draw = function(x, y)
  love.graphics.setCanvas(oam.canvas)
  love.graphics.clear()
  love.graphics.setColor(0.75, 0.75, 0.75)
  love.graphics.rectangle("fill", 0, 0, 160, 400)
  oam.draw_sprites()
  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(1, 1, 1)
  love.graphics.push()
  love.graphics.scale(2, 2)
  love.graphics.draw(oam.canvas, x / 2, y / 2)
  love.graphics.pop()
end

return oam
