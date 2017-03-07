local vram = {}

vram.width = 256

vram.init = function(gameboy)
  vram.canvas = love.graphics.newCanvas(256, 800)
  vram.tile_imagedata = love.image.newImageData(256, 256)
  vram.tile_image = love.graphics.newImage(vram.tile_imagedata)

  vram.gameboy = gameboy
end

vram.draw = function(x, y)
  love.graphics.setCanvas(vram.canvas)
  love.graphics.clear()
  local registers = vram.gameboy.graphics.registers

  love.graphics.print("Tile Data", 0, 0)
  vram.draw_tiles(vram.gameboy, 0, 20, 32, 1)

  love.graphics.print("Background", 0, 126)
  vram.draw_background(vram.gameboy, registers.background_tilemap, registers.background_attr, 0, 146, 1)

  love.graphics.print("Window", 0, 412)
  vram.draw_background(vram.gameboy, registers.window_tilemap, registers.window_attr, 0, 432, 1)

  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(vram.canvas, x, y)
end

vram.draw_tile = function(gameboy, tile, attr, sx, sy)
  local palette = gameboy.graphics.palette.bg
  if attr ~= nil then
    palette = attr.palette
  end

  for x = 0, 7 do
    for y = 0, 7 do
      local index = tile[x][y]
      local color = palette[index]
      vram.tile_imagedata:setPixel(sx + x, sy + y, color[1], color[2], color[3], 255)
    end
  end
end

vram.draw_tiles = function(gameboy, dx, dy, tiles_across, scale, bank)
  bank = bank or 0
  -- Clear out the tile image
  vram.tile_imagedata:mapPixel(function()
    return 0, 0, 0, 0
  end)
  local x = 0
  local y = 0
  local tiles = vram.gameboy.graphics.cache.tiles
  for i = 0, 384 - 1 do
    vram.draw_tile(gameboy, tiles[i], nil, x, y)
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
  vram.tile_image:refresh()
  love.graphics.draw(vram.tile_image, dx / scale, dy / scale)
  love.graphics.pop()
end

function vram.draw_background(gameboy, map, attrs, dx, dy, scale)
  -- Clear out the tile image
  vram.tile_imagedata:mapPixel(function()
    return 0, 0, 0, 0
  end)

  local tile_data = gameboy.graphics.registers.tile_select
  for x = 0, 31 do
    for y = 0, 31 do
      local tile = map[x][y]
      local attr = attrs[x][y]
      vram.draw_tile(gameboy, tile, attr, x * 8, y * 8)
    end
  end
  love.graphics.setCanvas(vram.canvas)
  love.graphics.setColor(255, 255, 255)
  love.graphics.push()
  love.graphics.scale(scale, scale)
  --love.graphics.draw(vram.tile_canvas, dx / scale, dy / scale)
  vram.tile_image:refresh()
  love.graphics.draw(vram.tile_image, dx / scale, dy / scale)
  love.graphics.pop()
end

return vram
