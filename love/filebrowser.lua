local filebrowser = {}

filebrowser.pwd = "games/"
filebrowser.cursor_pos = 0
filebrowser.scroll_pos = 0
filebrowser.items = {}

local ffi_status, ffi
if type(jit) == "table" and jit.status() then
  ffi_status, ffi = pcall(require, "ffi")
end

-- Note: the calling code will need to replace these dummy functions with
-- platform specific code for the filebrowser to actually get directory
-- listings.
filebrowser.is_directory = function()
  return false
end

filebrowser.get_directory_items = function()
  return {}
end

filebrowser.load_file = function()
  -- Does nothing!
end

filebrowser.init = function(gameboy)
  filebrowser.image_data = love.image.newImageData(256, 256)
  if ffi_status then
    filebrowser.raw_image_data = ffi.cast("luaGB_pixel*", filebrowser.image_data:getPointer())
  end
  filebrowser.image = love.graphics.newImage(filebrowser.image_data)
  filebrowser.font = love.image.newImageData("images/5x3font.png")
  filebrowser.round_button = love.image.newImageData("images/round_button.png")
  filebrowser.pill_button = love.image.newImageData("images/pill_button.png")
  filebrowser.palette_chooser = love.image.newImageData("images/palette_chooser.png")
  filebrowser.d_pad = love.image.newImageData("images/d-pad.png")
  filebrowser.logo = love.image.newImageData("images/logo.png")
  filebrowser.folder = love.image.newImageData("images/folder.png")
  filebrowser.dango = {}
  for i = 0, 8 do
    filebrowser.dango[i] = love.image.newImageData("images/dango_" .. i .. ".png")
  end
  filebrowser.gameboy = gameboy

  filebrowser.game_screen = {}
  for y = 0, 143 do
    filebrowser.game_screen[y] = {}
    for x = 0, 159 do
      filebrowser.game_screen[y][x] = {255, 255, 255}
    end
  end

  filebrowser.refresh_items()
end

filebrowser.draw_background = function(sx, sy)
  local palette = filebrowser.gameboy.graphics.palette.dmg_colors
  for x = 0, 159 do
    for y = 0, 143 do
      local tx = math.floor((x + sx) / 8)
      local ty = math.floor((y + sy) / 8)
      if (tx + ty) % 2 == 0 then
        filebrowser.game_screen[y][x] = palette[0]
      else
        filebrowser.game_screen[y][x] = palette[1]
      end
    end
  end
end

filebrowser.draw_string = function(str, dx, dy, color, max_x)
  max_x = max_x or 159
  for i = 1, #str do
    local char = string.byte(str, i)
    if 31 < char and char < 128 then
      char = char - 32
      local font_x = char * 4
      local font_y = 0
      for x = 0, 3 do
        if i * 4 - 4 + x + dx < max_x then
          for y = 0, 5 do
            if y + dy <= 143 then
              local r, g, b, a = filebrowser.font:getPixel(font_x + x, font_y + y)
              if a > 0 then
                r = color[1] * r
                g = color[2] * g
                b = color[3] * b
                filebrowser.game_screen[y + dy][i * 4 - 4 + x + dx] = {r, g, b}
              end
            end
          end
        end
      end
    end
  end
end

filebrowser.draw_rectangle = function(dx, dy, width, height, color, filled)
  for x = dx, dx + width - 1 do
    for y = dy, dy + height - 1 do
      if filled or y == dy or y == dy + height - 1 or x == dx or x == dx + width - 1 then
        filebrowser.game_screen[y][x] = color
      end
    end
  end
end

filebrowser.draw_shadow_pixel = function(x, y)
  local palette = filebrowser.gameboy.graphics.palette.dmg_colors
  if filebrowser.game_screen[y][x] == palette[2] then
    filebrowser.game_screen[y][x] = palette[3]
  end
  if filebrowser.game_screen[y][x] == palette[1] then
    filebrowser.game_screen[y][x] = palette[2]
  end
  if filebrowser.game_screen[y][x] == palette[0] then
    filebrowser.game_screen[y][x] = palette[1]
  end
end

filebrowser.draw_shadow = function(dx, dy, width, height)
  for x = dx, dx + width - 1 do
    for y = dy, dy + height - 1 do
      filebrowser.draw_shadow_pixel(x, y)
    end
  end
end

filebrowser.draw_image = function(sx, sy, image)
  local palette = filebrowser.gameboy.graphics.palette.dmg_colors
  for x = 0, image:getWidth() - 1 do
    for y = 0, image:getHeight() - 1 do
      local r, g, b, a = image:getPixel(x, y)
      if a > 0 then
        -- image:getPixel returns values from 0.0 - 1.0 starting in Love 11.0.1... which is annoying
        -- because we need the original un-modified value to use as a lookup. For now, we cheat and
        -- multiply back into the space we need:
        r = r * 255

        if r == 127 then
          filebrowser.draw_shadow_pixel(sx + x, sy + y)
        end
        if r == 0 then
          filebrowser.game_screen[sy + y][sx + x] = palette[3]
        end
        if r == 64 then
          filebrowser.game_screen[sy + y][sx + x] = palette[2]
        end
        if r == 128 then
          filebrowser.game_screen[sy + y][sx + x] = palette[1]
        end
        if r == 255 then
          filebrowser.game_screen[sy + y][sx + x] = palette[0]
        end
      end
    end
  end
end

filebrowser.shadow_box = function(x, y, width, height)
  local palette = filebrowser.gameboy.graphics.palette.dmg_colors
  filebrowser.draw_shadow(x + 1, y + 1, width, height)
  filebrowser.draw_rectangle(x, y, width, height, palette[0], true)
  filebrowser.draw_rectangle(x, y, width, height, palette[3])
end

filebrowser.refresh_items = function()
  local pwd_items = love.filesystem.getDirectoryItems(filebrowser.pwd)
  filebrowser.items = {}
  filebrowser.cursor_pos = 0
  filebrowser.scroll_pos = 0

  if filebrowser.pwd ~= "games/" then
    table.insert(filebrowser.items, "..")
  end

  -- Sort directories first
  for _, path in pairs(pwd_items) do
    if love.filesystem.isDirectory(filebrowser.pwd .. path) then
      table.insert(filebrowser.items, path)
    end
  end

  -- Then not directories (Everything else)
  for _, path in pairs(pwd_items) do
    if not love.filesystem.isDirectory(filebrowser.pwd .. path) then
      table.insert(filebrowser.items, path)
    end
  end
end

filebrowser.update = function()
  -- do nothing?
end

filebrowser.select_at_cursor = function()
  local cursor_item = filebrowser.items[filebrowser.cursor_pos + 1]
  if cursor_item == nil then
    return
  end
  if cursor_item == ".." then
    -- remove the last directory off of pwd
    local index = string.find(filebrowser.pwd, "[^/]*/$")
    filebrowser.pwd = string.sub(filebrowser.pwd, 1, index - 1)
    print("new pwd: ", filebrowser.pwd)
    filebrowser.refresh_items()
    return
  end
  if love.filesystem.isDirectory(filebrowser.pwd .. cursor_item) then
    filebrowser.pwd = filebrowser.pwd .. cursor_item .. "/"
    filebrowser.refresh_items()
    return
  end
  -- We must assume this is a file! Try to load it
  filebrowser.load_file(filebrowser.pwd .. cursor_item)
end

filebrowser.keyreleased = function(key)
  if key == "up" and filebrowser.cursor_pos > 0 then
    filebrowser.cursor_pos = filebrowser.cursor_pos - 1
    if filebrowser.cursor_pos < filebrowser.scroll_pos + 1 and filebrowser.scroll_pos > 0 then
      filebrowser.scroll_pos = filebrowser.cursor_pos - 1
    end
  end

  if key == "down" and filebrowser.cursor_pos < #filebrowser.items - 1 then
    filebrowser.cursor_pos = filebrowser.cursor_pos + 1
    if filebrowser.cursor_pos > filebrowser.scroll_pos + 9 then
      filebrowser.scroll_pos = filebrowser.cursor_pos - 9
    end
  end

  if key == "return" or key == "x" then
    filebrowser.select_at_cursor()
  end
end

local palettes = {}
local palette_index = 1
palettes[1] = {{255, 255, 255}, {192, 192, 192}, {128, 128, 128}, {0, 0, 0}}
palettes[2] = {{215, 215, 215}, {140, 124, 114}, {100, 82, 73}, {45, 45, 45}}
palettes[3] = {{224, 248, 208}, {136, 192, 112}, {52, 104, 86}, {8, 24, 32}}


filebrowser.switch_palette = function(button)
  if button == 1 then
    palette_index = palette_index + 1
  end
  if button == 2 then
    palette_index = palette_index - 1
  end
  if palette_index < 1 then
    palette_index = #palettes
  end
  if palette_index > #palettes then
    palette_index = 1
  end
  filebrowser.gameboy.graphics.palette.set_dmg_colors(unpack(palettes[palette_index]))
end

local dango_index = 0
filebrowser.random_dango = function(button)
  dango_index = math.random(0, 8)
end

filebrowser.open_save_directory = function(button)
  love.system.openURL("file://"..love.filesystem.getSaveDirectory())
end

local regions = {}
regions.palette = {x=134,y=4,width=20,height=8,action=filebrowser.switch_palette}
regions.dango = {x=7,y=0,width=21,height=14,action=filebrowser.random_dango}
regions.folder = {x=110,y=0,width=29,height=14,action=filebrowser.open_save_directory}

filebrowser.mousepressed = function(x, y, button)
  for _, region in pairs(regions) do
    if x >= region.x and x < region.x + region.width and y >= region.y and y < region.y + region.height then
      region.action(button)
    end
  end
end

-- used for animations. Assume 60FPS, don't overcomplicate things.
filebrowser.frame_counter = 0
filebrowser.draw = function(dx, dy, scale)
  local palette = filebrowser.gameboy.graphics.palette.dmg_colors

  -- run the drawing functions to the virtual game screen
  local frames = filebrowser.frame_counter
  local scroll_amount = math.floor(frames / 8)
  filebrowser.draw_background(scroll_amount, scroll_amount * -1)
  filebrowser.shadow_box(7, 15, 146, 81)

  -- highlight box
  filebrowser.draw_rectangle(8, 17 + ((filebrowser.cursor_pos - filebrowser.scroll_pos) * 7), 144, 7, palette[2], true)

  -- Filebrowser / game selection menu
  local y = 18
  local i = 0 - filebrowser.scroll_pos
  for _, item in pairs(filebrowser.items) do
    if i >= 0 and i < 11 then
      local color = palette[2]
      if i + filebrowser.scroll_pos == filebrowser.cursor_pos then
        color = palette[3]
      end
      filebrowser.draw_string(item, 10, y, color, 152)
      y = y + 7
    end
    i = i + 1
  end

  -- Misc. Options
  filebrowser.draw_image(133,   4, filebrowser.palette_chooser)
  filebrowser.draw_image(136, 108, filebrowser.round_button)    -- A
  filebrowser.draw_image(124, 120, filebrowser.round_button)    -- B
  filebrowser.draw_image( 86, 114, filebrowser.pill_button)     -- Start
  filebrowser.draw_image( 51, 114, filebrowser.pill_button)     -- Select
  filebrowser.draw_image( 12, 104, filebrowser.d_pad)
  filebrowser.draw_image( 111,  0, filebrowser.folder)

  -- Key mappings
  filebrowser.draw_string("X", 140, 111, palette[3])      -- A
  filebrowser.draw_string("Z", 128, 123, palette[3])      -- B
  filebrowser.draw_string("ENTER", 92, 117, palette[3])   -- Start
  filebrowser.draw_string("RSHIFT", 55, 117, palette[3])  -- Select

  -- Logo
  filebrowser.draw_image(7, 0, filebrowser.dango[dango_index])
  filebrowser.draw_image(22, 0, filebrowser.logo)

  -- Blit the virtual game screen to a love canvas
  local pixels = filebrowser.game_screen
  local image_data = filebrowser.image_data
  local raw_image_data = filebrowser.raw_image_data
  local stride = image_data:getWidth()
  for y = 0, 143 do
    for x = 0, 159 do
      if raw_image_data then
        local pixel = raw_image_data[y*stride+x]
        local v_pixel = pixels[y][x]
        pixel.r = v_pixel[1]
        pixel.g = v_pixel[2]
        pixel.b = v_pixel[3]
        pixel.a = 255
      else
        image_data:setPixel(x, y, pixels[y][x][1], pixels[y][x][2], pixels[y][x][3], 255)
      end
    end
  end

  love.graphics.setCanvas()
  love.graphics.setColor(1, 1, 1)
  filebrowser.image:replacePixels(filebrowser.image_data)
  love.graphics.push()
  love.graphics.scale(scale, scale)
  love.graphics.draw(filebrowser.image, dx / scale, dy / scale)
  love.graphics.pop()

  filebrowser.frame_counter = filebrowser.frame_counter + 1
end

return filebrowser
