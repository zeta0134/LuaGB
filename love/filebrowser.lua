local filebrowser = {}

filebrowser.pwd = "games/"
filebrowser.cursor_pos = 0
filebrowser.scroll_pos = 0
filebrowser.items = {}

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
  filebrowser.image_data = love.image.newImageData(160, 144)
  filebrowser.image = love.graphics.newImage(filebrowser.image_data)
  filebrowser.font = love.image.newImageData("5x3font.png")
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
  local palette = filebrowser.gameboy.graphics.screen_colors
  for x = 0, 159 do
    for y = 0, 143 do
      local tx = math.floor((x + sx) / 4)
      local ty = math.floor((y + sy) / 4)
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
      local font_x = (char % 32) * 4
      local font_y = math.floor(char / 32) * 6
      for x = 0, 3 do
        if i * 4 + x + dx < max_x then
          for y = 0, 5 do
            if y + dy <= 143 then
              local r, g, b, a = filebrowser.font:getPixel(font_x + x, font_y + y)
              if a > 0 then
                r = color[1] * r
                g = color[2] * g
                b = color[3] * b
                filebrowser.game_screen[y + dy][i * 4 + x + dx] = {r, g, b}
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

filebrowser.draw_shadow = function(dx, dy, width, height)
  local palette = filebrowser.gameboy.graphics.screen_colors
  for x = dx, dx + width - 1 do
    for y = dy, dy + height - 1 do
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
  end
end

filebrowser.shadow_box = function(x, y, width, height)
  local palette = filebrowser.gameboy.graphics.screen_colors
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

-- used for animations. Assume 60FPS, don't overcomplicate things.
filebrowser.frame_counter = 0
filebrowser.draw = function()
  local palette = filebrowser.gameboy.graphics.screen_colors

  -- run the drawing functions to the virtual game screen
  local frames = filebrowser.frame_counter
  local scroll_amount = math.floor(frames / 8)
  filebrowser.draw_background(scroll_amount, scroll_amount * -1)
  filebrowser.shadow_box(7, 15, 146, 81)

  -- highlight box
  filebrowser.draw_rectangle(8, 17 + ((filebrowser.cursor_pos - filebrowser.scroll_pos) * 7), 144, 7, palette[2], true)

  local y = 18
  local i = 0 - filebrowser.scroll_pos
  for _, item in pairs(filebrowser.items) do
    if i >= 0 and i < 11 then
      local color = palette[2]
      if i + filebrowser.scroll_pos == filebrowser.cursor_pos then
        color = palette[3]
      end
      filebrowser.draw_string(item, 10, y, color)
      y = y + 7
    end
    i = i + 1
  end

  -- Blit the virtual game screen to a love canvas
  for x = 0, 159 do
    for y = 0, 143 do
      filebrowser.image_data:setPixel(x, y, unpack(filebrowser.game_screen[y][x]))
    end
  end

  love.graphics.setCanvas()
  love.graphics.setColor(255, 255, 255)
  filebrowser.image:refresh()
  love.graphics.push()
  love.graphics.scale(2, 2)
  love.graphics.draw(filebrowser.image, 0, 0)
  love.graphics.pop()

  filebrowser.frame_counter = filebrowser.frame_counter + 1
end

return filebrowser
