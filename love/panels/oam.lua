local oam = {}

oam.width = 320

oam.init = function(gameboy)
  oam.canvas = love.graphics.newCanvas(320, 800)
  oam.gameboy = gameboy
  oam.sprite_canvas = love.graphics.newCanvas(8,16)
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

  return sprite_tile, sprite_x, sprite_y, sprite_flags
end

oam.draw_sprites = function()
  local cell_size = 80
  local sprites_per_row = 4
  local sprite_scaling = 4

  local sprite_size = 8
  if oam.gameboy.graphics.LCD_Control.LargeSprites() then
    sprite_size = 16
  end
  local x = 0
  local y = 0
  for i = 0, 39 do
    -- background square
    local color = 16
    if ((x + y) % 2) == 0 then
      color = 32
    end
    -- draw the sprite
    love.graphics.setColor(color, color, color)
    love.graphics.rectangle("fill", x * cell_size, y * cell_size, cell_size, cell_size)
    love.graphics.setCanvas(oam.sprite_canvas)
    love.graphics.clear()
    local tile, sprite_x, sprite_y, flags = oam.draw_sprite((i * 4), 0, 0, sprite_size)
    love.graphics.setCanvas(oam.canvas)
    love.graphics.push()
    love.graphics.scale(sprite_scaling, sprite_scaling)
    love.graphics.setColor(255, 255, 255)
    love.graphics.draw(oam.sprite_canvas, (x * cell_size + sprite_scaling) / sprite_scaling, (y * cell_size + sprite_scaling) / sprite_scaling)
    love.graphics.pop()
    -- draw info about this sprite
    love.graphics.print(string.format("T-%02X", tile    ), x * cell_size + cell_size - 40, y * cell_size + 4)
    love.graphics.print(string.format("X-%02X", sprite_x), x * cell_size + cell_size - 40, y * cell_size + 22)
    love.graphics.print(string.format("Y-%02X", sprite_y), x * cell_size + cell_size - 40, y * cell_size + 40)
    love.graphics.print(string.format("F-%02X", flags   ), x * cell_size + cell_size - 40, y * cell_size + 58)
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
  oam.draw_sprites()
  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(oam.canvas, x, y)
end

return oam
