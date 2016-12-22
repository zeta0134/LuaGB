local oam = {}

oam.width = 256

oam.init = function(gameboy)
  oam.canvas = love.graphics.newCanvas(256, 800)
  oam.gameboy = gameboy
end

oam.draw_sprite = function(sprite_address, sx, sy, sprite_size)
  local graphics = oam.gameboy.graphics
  local io = oam.gameboy.io
  local ports = oam.gameboy.io.ports

  local sprite_y = graphics.oam[sprite_address]
  local sprite_x = graphics.oam[sprite_address + 1]
  local sprite_tile = graphics.oam[sprite_address + 2]
  if sprite_size == 16 then
    sprite_tile = bit32.band(sprite_tile, 0xFE)
  end
  local sprite_flags = graphics.oam[sprite_address + 3]

  local sprite_palette = io.ram[ports.OBP0]
  if bit32.band(sprite_flags, 0x10) ~= 0 then
    sprite_palette = io.ram[ports.OBP1]
  end

  local address = 0x8000 + (sprite_tile * 16)

  for y = 0, (sprite_size - 1) do
    for x = 0, 7 do
      local color = graphics.getColorFromTile(address, x, y, sprite_palette)
      love.graphics.setColor(color[1], color[2], color[3])
      love.graphics.points(0.5 + sx + x, 0.5 + sy + y)
    end
  end
end

oam.draw_sprites = function(sprites_per_row)
  local sprite_size = 8
  if oam.gameboy.graphics.LCD_Control.LargeSprites() then
    sprite_size = 16
  end
  local x = 0
  local y = 0
  for i = 0, 39 do
    oam.draw_sprite((i * 4), x * 32, y * 32, sprite_size)
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
  oam.draw_sprites(8)
  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(oam.canvas, x, y)
end

return oam
