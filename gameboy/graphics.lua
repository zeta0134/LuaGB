-- Various functions for manipulating IO in memory
local LCDC = function()
  return memory[0xFF40]
end

local STAT = function()
  return memory[0xFF41]
end

local setSTAT = function(value)
  memory[0xFF41] = value
end

LCD_Control = {}
LCD_Control.DisplayEnabled = function()
  return bit32.band(0x80, LCDC()) ~= 0
end

LCD_Control.WindowTilemap = function()
  if bit32.band(0x40, LCDC()) ~= 0 then
    return 0x9C00
  else
    return 0x9800
  end
end

LCD_Control.WindowEnabled = function()
  return bit32.band(0x20, LCDC()) ~= 0
end

LCD_Control.TileData = function()
  if bit32.band(0x10, LCDC()) ~= 0 then
    return 0x8000
  else
    return 0x9000
  end
end

LCD_Control.BackgroundTilemap = function()
  if bit32.band(0x08, LCDC()) ~= 0 then
    return 0x9C00
  else
    return 0x9800
  end
end

LCD_Control.LargeSprites = function()
  return bit32.band(0x04, LCDC()) ~= 0
end

LCD_Control.SpritesEnabled = function()
  return bit32.band(0x02, LCDC()) ~= 0
end

LCD_Control.BackgroundEnabled = function()
  return bit32.band(0x01, LCDC()) ~= 0
end

Status = {}
Status.Coincidence_InterruptEnabled = function()
  return bit32.band(0x20, STAT()) ~= 0
end

Status.OAM_InterruptEnabled = function()
  return bit32.band(0x10, STAT()) ~= 0
end

Status.VBlank_InterruptEnabled = function()
  return bit32.band(0x08, STAT()) ~= 0
end

Status.HBlank_InterruptEnabled = function()
  return bit32.band(0x06, STAT()) ~= 0
end

Status.Mode = function()
  return bit32.band(memory[0xFF41], 0x3)
end

Status.SetMode = function(mode)
  memory[0xFF41] = bit32.band(STAT(), 0xF8) + bit32.band(mode, 0x3)
  if mode == 0 then
    -- HBlank
    --draw_scanline(scanline())
  end
  if mode == 1 then
    if LCD_Control.DisplayEnabled() then
      -- VBlank
      --draw_screen()
    else
      --clear_screen()
    end
  end
end

local SCY = function()
  return memory[0xFF42]
end

local SCX = function()
  return memory[0xFF43]
end

local WY = function()
  return memory[0xFF4A]
end

local WX = function()
  return memory[0xFF4B]
end

scanline = function()
  return memory[0xFF44]
end

local set_scanline = function(value)
  memory[0xFF44] = value
end

local scanline_compare = function()
  return memory[0xFF45]
end

local last_edge = 0
local handle_mode = {}

time_at_this_mode = function()
  return clock - last_edge
end

-- HBlank: Period between scanlines
handle_mode[0] = function()
  if clock - last_edge > 204 then
    last_edge = last_edge + 204
    set_scanline(scanline() + 1)
    -- If enabled, fire an HBlank interrupt
    if bit32.band(STAT(), 0x08) ~= 0 then
      request_interrupt(Interrupt.LCDStat)
    end
    if scanline() == scanline_compare() then
      -- set the LY compare bit
      setSTAT(bit32.bor(STAT(), 0x4))
      if bit32.band(STAT(), 0x40) ~= 0 then
        request_interrupt(Interrupt.LCDStat)
      end
    else
      -- clear the LY compare bit
      setSTAT(bit32.band(STAT(), 0xFB))
    end
    if scanline() >= 144 then
      Status.SetMode(1)
      request_interrupt(Interrupt.VBlank)
      if bit32.band(STAT(), 0x10) ~= 0 then
        -- This is weird; LCDStat mirrors VBlank?
        request_interrupt(Interrupt.LCDStat)
      end
      -- TODO: Draw the real screen here?
    else
      Status.SetMode(2)
      if bit32.band(STAT(), 0x20) ~= 0 then
        request_interrupt(Interrupt.LCDStat)
      end
    end
  end
end

--VBlank: nothing to do except wait for the next frame
handle_mode[1] = function()
  if clock - last_edge > 456 then
    last_edge = last_edge + 456
    set_scanline(scanline() + 1)
  end
  if scanline() >= 154 then
    set_scanline(0)
    Status.SetMode(2)
    if bit32.band(STAT(), 0x20) ~= 0 then
      request_interrupt(Interrupt.LCDStat)
    end
  end
  if scanline() == scanline_compare() then
    -- TODO: fire LCD STAT interrupt, and set appropriate flag
  end
end

-- OAM Read: OAM cannot be accessed
handle_mode[2] = function()
  if clock - last_edge > 80 then
    last_edge = last_edge + 80
    Status.SetMode(3)
  end
end

-- VRAM Read: Neither VRAM, OAM, nor CGB palettes can be read
handle_mode[3] = function()
  if clock - last_edge > 172 then
    last_edge = last_edge + 172
    Status.SetMode(0)
    -- TODO: Fire HBlank interrupt here!!
    -- TODO: Draw one scanline of graphics here!
  end
end

function initialize_graphics()
  Status.SetMode(2)
end

function update_graphics()
  handle_mode[Status.Mode()]()
end

colors = {}
colors[0] = {0, 0, 0}
colors[1] = {128, 128, 128}
colors[2] = {192, 192, 192}
colors[3] = {255, 255, 255}

game_screen = {}
for y = 0, 143 do
  game_screen[y] = {}
  for x = 1, 160 * 4 + 4 do
    game_screen[y][x] = 255
  end
end

function plot_pixel(buffer, x, y, r, g, b)
  local weird_offset = 4
  buffer[y][x + weird_offset    ] = r
  buffer[y][x + weird_offset + 1] = g
  buffer[y][x + weird_offset + 2] = b
  buffer[y][x + weird_offset + 3] = 255
end

function debug_draw_screen()
  for i = 0, 143 do
    draw_scanline(i)
  end
end

function getColorFromTilemap(map_address, x, y)
  local tile_x = bit32.rshift(x, 3)
  local tile_y = bit32.rshift(y, 3)
  local tile_index = memory[map_address + (tile_y * 32) + (tile_x)]
  if LCD_Control.TileData() == 0x8800 then
    if tile_index > 127 then
      tile_index = tile_index - 256
    end
  end
  tile_address = LCD_Control.TileData() + index * 16

  local subpixel_x = x - (tile_x * 8)
  local subpixel_y = y - (tile_y * 8)
  -- move to the row we need this pixel from
  while subpixel_y >= 0 do
    tile_address = tile_address + 2
    subpixel_y = subpixel_y - 1
  end
  -- grab the pixel color we need, and translate it into a palette index
  local palette_index = 0
  if bit32.band(memory[tile_address], bit32.lshift(0x1, 7 - subpixel_x)) ~= 0 then
    palette_index = palette_index + 1
  end
  tile_address = tile_address + 1
  if bit32.band(memory[tile_address], bit32.lshift(0x1, 7 - subpixel_x)) ~= 0 then
    palette_index = palette_index + 2
  end
  -- finally, return the color from the table, based on this index
  -- todo: allow specifying the palette?
  return colors[palette_index]
end

function draw_scanline(scanline)
  local bg_y = scanline + SCY()
  local bg_x = SCX()
  -- wrap the map in the Y direction
  if bg_y > 256 then
    bg_y = bg_y - 256
  end
  local w_y = scanline + WY()
  local w_x = WX() + 7
  local window_visible = false
  if w_x <= 166 and w_y <= 143 then
    window_visible = true
  end

  for x = 0, 159 do
    if LCD_Control.BackgroundEnabled() then
      local bg_color = getColorFromTilemap(LCD_Control.BackgroundTilemap(), bg_x, bg_y)
      plot_pixel(game_screen, x, scanline, unpack(bg_color))
    end
    if LCD_Control.WindowEnabled() and window_visible then
      -- The window doesn't wrap, so make sure these coordinates are valid
      -- (ie, inside the window map) before attempting to plot a pixel
      if w_x > 0 and w_x < 256 and w_y > 0 and w_y < 256 then
        local window_color = getColorFromTilemap(LCD_Control.WindowTilemap(), w_x, w_y)
        plot_pixel(game_screen, x, scanline, unpack(window_color))
      end
    end
    bg_x = bg_x + 1
    if bg_x >= 256 then
      bg_x = bg_x - 256
    end
    w_x = w_x + 1
  end
end

function draw_half_scale(destination, source, dx, dy)
  gpu.bindTexture(source)
  width, height = gpu.getSize()
  for x = 0, width, 2 do
    for y = 0, height, 2 do
      gpu.bindTexture(source)
      r, g, b = gpu.getPixels(x, y)
      gpu.bindTexture(destination)
      gpu.setColor(r, g, b)
      gpu.plot(dx + (x / 2), dy + (y / 2))
    end
  end
end

function draw_tile(address, px, py)
  local x = 0
  local y = 0
  for y = 0, 7 do
    local low_bits = memory[address]
    address = address + 1
    local high_bits = memory[address]
    address = address + 1
    for x = 0, 7 do
      local color_index = 0
      if bit32.band(low_bits, bit32.lshift(0x1, 7 - x)) ~= 0 then
        color_index = color_index + 1
      end
      if bit32.band(high_bits, bit32.lshift(0x1, 7 - x)) ~= 0 then
        color_index = color_index + 2
      end
      gpu.setColor(unpack(colors[color_index]))
      gpu.plot(px + x, py + y)
    end
  end
end

function draw_tiles()
  gpu.bindTexture(0)
  gpu.startFrame()
  gpu.setColor(192,255,192)
  gpu.fill()
  local i = 0
  local x = 0
  local y = 0
  while i < 384 do
    draw_tile(0x8000 + (i * 16), x, y)
    x = x + 8
    if x >= 256 then
      x = 0
      y = y + 8
    end
    i = i + 1
  end
  gpu.endFrame()
end

function draw_background()
  gpu.startFrame()
  gpu.bindTexture(background_texture)
  gpu.setColor(255,192,192)
  gpu.fill()

  for x = 0, 32 do
    for y = 0, 32 do
      -- figure out the tile index
      address = LCD_Control.BackgroundTilemap() + (y * 32) + (x)
      index = memory[address]
      if LCD_Control.TileData() == 0x8800 then
        if index > 127 then
          index = index - 256
        end
      end
      --write(index .. ",")
      draw_tile(LCD_Control.TileData() + (index * 16), x * 8, y * 8)
    end
  end
  gpu.bindTexture(0)
  draw_half_scale(0, background_texture, 0, 0)
  gpu.endFrame()
end

function draw_window()
  gpu.startFrame()
  gpu.bindTexture(background_texture)
  gpu.setColor(255,192,192)
  gpu.fill()

  for x = 0, 32 do
    for y = 0, 32 do
      -- figure out the tile index
      address = LCD_Control.WindowTilemap() + (y * 32) + (x)
      index = memory[address]
      if LCD_Control.TileData() == 0x8800 then
        if index > 127 then
          index = index - 256
        end
      end
      --write(index .. ",")
      draw_tile(LCD_Control.TileData() + (index * 16), x * 8, y * 8)
    end
  end
  gpu.bindTexture(0)
  --gpu.drawTexture(background_texture, 0, 0)
  draw_half_scale(0, background_texture, 128, 0)
  gpu.endFrame()
end

function draw_sprites()
  gpu.startFrame()
  gpu.bindTexture(0)
  gpu.setColor(255,255,192)
  gpu.fill()
  local count = 0
  for i = 0, 39 do
    local oam_entry = 0xFE00 + (i * 4)
    local y = memory[oam_entry] - 16
    local x = memory[oam_entry + 1] - 8
    if y > -16 and y < 144 and x > -8 and x < 160 then
      -- sprite is onscreen!
      local sprite_tile = memory[oam_entry + 2]
      draw_tile(0x8000 + (sprite_tile * 16), x, y)
      count = count + 1
    end
  end
  print("Displayed " .. count .. " sprites")
  gpu.endFrame()
end
