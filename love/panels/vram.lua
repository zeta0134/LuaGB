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
  if vram.gameboy.graphics.LCD_Control.BackgroundTilemap() == 0x9800 then
    vram.draw_background(vram.gameboy, vram.gameboy.graphics.map_0, 0, 146, 1)
  else
    vram.draw_background(vram.gameboy, vram.gameboy.graphics.map_1, 0, 146, 1)
  end

  love.graphics.print("Window", 0, 412)
  if vram.gameboy.graphics.LCD_Control.WindowTilemap() == 0x9800 then
    vram.draw_background(vram.gameboy, vram.gameboy.graphics.map_0, 0, 432, 1)
  else
    vram.draw_background(vram.gameboy, vram.gameboy.graphics.map_1, 0, 432, 1)
  end

  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(vram.canvas, x, y)
end

vram.draw_tile = function(gameboy, tile_index, sx, sy)
  local tile = gameboy.graphics.tiles[tile_index]
  for x = 0, 7 do
    for y = 0, 7 do
      local index = tile[x][y]
      local color = gameboy.graphics.getColorFromIndex(index)
      love.graphics.setColor(color[1], color[2], color[3])
      love.graphics.points(0.5 + sx + x, 0.5 + sy + y)
    end
  end
end

vram.draw_tiles = function(gameboy, dx, dy, tiles_across, scale)
  love.graphics.setCanvas(vram.tile_canvas)
  love.graphics.clear()
  local x = 0
  local y = 0
  for i = 0, 384 - 1 do
    vram.draw_tile(gameboy, i, x, y)
    x = x + 8
    if x >= tiles_across * 8 then
      x = 0
      y = y + 8
    end
  end
  love.graphics.setColor(255, 255, 255)
  love.graphics.setCanvas(vram.canvas)
  love.graphics.push()
  love.graphics.scale(scale, scale)
  love.graphics.draw(vram.tile_canvas, dx / scale, dy / scale)
  love.graphics.pop()
end

function vram.draw_background(gameboy, map, dx, dy, scale)
  love.graphics.setCanvas(vram.tile_canvas)
  love.graphics.clear()
  local tile_data = gameboy.graphics.LCD_Control.TileData()
  for x = 0, 31 do
    for y = 0, 31 do
      local index = map[x][y]
      if tile_data == 0x9000 then
        -- convert index to signed
        if index > 127 then
          index = index - 256
        end
        -- add offset to re-root at tile 256 (so effectively, we read from tile 192 - 384)
        index = index + 256
      end
      vram.draw_tile(gameboy, index, x * 8, y * 8)
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
