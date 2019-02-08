local vram = {}

vram.width = 264 * 2

vram.init = function(gameboy)
  vram.canvas = love.graphics.newCanvas(264, 400)
  vram.tile_imagedata = love.image.newImageData(256, 256)
  vram.tile_image = love.graphics.newImage(vram.tile_imagedata)

  vram.active_bg = 0
  vram.active_bank = 0
  vram.selected_palette = gameboy.graphics.palette.dmg_colors

  vram.background_image = love.graphics.newImage("images/debug_vram_background.png")
  vram.bank_1_image = love.graphics.newImage("images/debug_tiles_1.png")
  vram.map_wx_image = love.graphics.newImage("images/debug_maps_wx.png")
end

vram.set_bank_0 = function() vram.active_bank = 0 end
vram.set_bank_1 = function() vram.active_bank = 1 end
vram.set_map_bg = function() vram.active_bg = 0 end
vram.set_map_wx = function() vram.active_bg = 1 end

local regions = {}
regions.bank_0 = {x=33,y=10,width=9,height=10,action=vram.set_bank_0}
regions.bank_1 = {x=43,y=10,width=9,height=10,action=vram.set_bank_1}
regions.map_bg = {x=30,y=129,width=13,height=10,action=vram.set_map_bg}
regions.map_wx = {x=44,y=129,width=13,height=10,action=vram.set_map_wx}

vram.mousepressed = function(x, y, button)
  x = x / 2
  y = y / 2
  for _, region in pairs(regions) do
    if x >= region.x and x < region.x + region.width and y >= region.y and y < region.y + region.height then
      region.action(button)
    end
  end
end

vram.draw = function(x, y, gameboy)
  love.graphics.setCanvas(vram.canvas)
  love.graphics.clear()
  love.graphics.draw(vram.background_image, 0, 0)
  local registers = gameboy.graphics.registers

  vram.draw_tiles(gameboy, 4, 21, 32, vram.active_bank)
  if vram.active_bank == 1 then
    love.graphics.draw(vram.bank_1_image, 2, 9)
  end

  if vram.active_bg == 0 then
    vram.draw_background(gameboy, registers.background_tilemap, registers.background_attr, 4, 140, 1)
  else
    love.graphics.draw(vram.map_wx_image, 2, 128)
    vram.draw_background(gameboy, registers.window_tilemap, registers.window_attr, 4, 140, 1)
  end

  vram.draw_palettes(gameboy)

  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(1, 1, 1)
  love.graphics.push()
  love.graphics.scale(2, 2)
  love.graphics.draw(vram.canvas, x / 2, y / 2)
  love.graphics.pop()
end

vram.draw_palette = function(palette, x, y)
  if vram.selected_palette == palette then
    love.graphics.setColor(0.75, 0.75, 0.75)
    love.graphics.rectangle("line", x-1, y-1, 19, 7)
    love.graphics.setColor(0.50, 0.50, 0.50)
    love.graphics.rectangle("line", x, y, 19, 7)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x+1, y+1, 17, 5)
    x = x + 1
    y = y + 1
  end
  for i = 0, 3 do
    love.graphics.setColor(palette[i][1] / 255, palette[i][2] / 255, palette[i][3] / 255)
    love.graphics.rectangle("fill", x + (i * 4), y, 4, 4)
  end
end

vram.draw_palettes = function(gameboy)
  vram.draw_palette(gameboy.graphics.palette.dmg_colors, 244, 12)
  vram.draw_palette(gameboy.graphics.palette.bg        ,  90, 12)
  vram.draw_palette(gameboy.graphics.palette.obj0      , 134, 12)
  vram.draw_palette(gameboy.graphics.palette.obj1      , 156, 12)

  local color_bg_palettes = gameboy.graphics.palette.color_bg
  for index, palette in pairs(color_bg_palettes) do
    vram.draw_palette(palette, 90 + (index * 22), 131)
  end

  local color_obj_palettes = gameboy.graphics.palette.color_obj
  for index, palette in pairs(color_obj_palettes) do
    vram.draw_palette(palette, 90 + (index * 22), 122)
  end
  love.graphics.setColor(1, 1, 1)
end

vram.draw_tile = function(gameboy, tile, attr, sx, sy)
  local palette = vram.selected_palette
  if attr ~= nil then
    palette = attr.palette
  end

  for x = 0, 7 do
    for y = 0, 7 do
      local ty = y
      if attr ~= nil and attr.vertical_flip then
        ty = 7 - y
      end
      local index = tile[x][ty]
      local color = palette[index]
      vram.tile_imagedata:setPixel(sx + x, sy + y, color[1] / 255, color[2] / 255, color[3] / 255, 255)
    end
  end
end

vram.draw_tiles = function(gameboy, dx, dy, tiles_across, bank)
  bank = bank or 0
  -- Clear out the tile image
  vram.tile_imagedata:mapPixel(function()
    return 0, 0, 0, 0
  end)
  local x = 0
  local y = 0
  local tiles = gameboy.graphics.cache.tiles
  for i = 0, 384 - 1 do
    vram.draw_tile(gameboy, tiles[bank * 384 + i], nil, x, y)
    x = x + 8
    if x >= tiles_across * 8 then
      x = 0
      y = y + 8
    end
  end
  love.graphics.setColor(1, 1, 1)
  love.graphics.setCanvas(vram.canvas)
  vram.tile_image:replacePixels(vram.tile_imagedata)
  love.graphics.draw(vram.tile_image, dx, dy)
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
  love.graphics.setColor(1, 1, 1)
  love.graphics.push()
  love.graphics.scale(scale, scale)
  vram.tile_image:replacePixels(vram.tile_imagedata)
  love.graphics.draw(vram.tile_image, dx / scale, dy / scale)
  love.graphics.pop()
end

return vram
