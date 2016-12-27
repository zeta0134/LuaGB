local vram = {}

vram.width = 256

vram.init = function(gameboy)
  vram.canvas = love.graphics.newCanvas(256, 800)
  vram.tile_canvas = love.graphics.newCanvas(256, 256)
  vram.gameboy = gameboy
end

vram.draw = function(x, y)
  love.graphics.setCanvas(vram.canvas)
  love.graphics.clear()

  love.graphics.print("Tile Data", 0, 0)
  vram.draw_tiles(vram.gameboy, 0, 20, 32, 1)

  love.graphics.print("Background", 0, 126)
  vram.draw_tilemap(vram.gameboy, 0, 146, 0x9800, 1)

  love.graphics.print("Window", 0, 412)
  vram.draw_tilemap(vram.gameboy, 0, 432, 0x9C00, 1)

  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(vram.canvas, x, y)
end

vram.draw_tile = function(gameboy, address, sx, sy)
  for y = 0, 7 do
    for x = 0, 7 do
      local color = gameboy.graphics.getColorFromTile(address, x, y)
      love.graphics.setColor(color[1], color[2], color[3])
      love.graphics.points(0.5 + sx + x, 0.5 + sy + y)
    end
  end
end

vram.draw_tiles = function(gameboy, dx, dy, tiles_across, scale)
  love.graphics.setCanvas(vram.tile_canvas)
  love.graphics.clear()
  local tile_address = 0x8000
  local x = 0
  local y = 0
  for i = 0, 384 - 1 do
    vram.draw_tile(gameboy, tile_address, x, y)
    x = x + 8
    if x >= tiles_across * 8 then
      x = 0
      y = y + 8
    end
    tile_address = tile_address + 16
  end
  love.graphics.setColor(255, 255, 255)
  love.graphics.setCanvas(vram.canvas)
  love.graphics.push()
  love.graphics.scale(scale, scale)
  love.graphics.draw(vram.tile_canvas, dx / scale, dy / scale)
  love.graphics.pop()
end

function vram.draw_tilemap(gameboy, dx, dy, address, scale)
  love.graphics.setCanvas(vram.tile_canvas)
  love.graphics.clear()
  local tile_data = gameboy.graphics.LCD_Control.TileData()
  for y = 0, 255 do
    for x = 0, 255 do
      local color = gameboy.graphics.getColorFromTilemap(address, tile_data, x, y)
      love.graphics.setColor(color[1], color[2], color[3])
      love.graphics.points(0.5 + x, 0.5 + y)
    end
  end
  love.graphics.setCanvas(vram.canvas)
  love.graphics.setColor(255, 255, 255)
  love.graphics.push()
  love.graphics.scale(scale, scale)
  love.graphics.draw(vram.tile_canvas, dx / scale, dy / scale)
  love.graphics.pop()
end

return vram
