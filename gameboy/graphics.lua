local interrupts = require("gameboy/interrupts")
local io = require("gameboy/io")
local memory = require("gameboy/memory")
local timers = require("gameboy/timers")

local graphics = {}

--just for shortening access
local ports = io.ports

-- Internal Variables
graphics.vblank_count = 0
graphics.last_edge = 0

graphics.game_screen = {}

graphics.clear_screen = function()
  for y = 0, 143 do
    graphics.game_screen[y] = {}
    for x = 0, 159 do
      graphics.game_screen[y][x] = {255, 255, 255}
    end
  end
end

-- Initialize VRAM blocks in main memory
-- TODO: Implement access restrictions here based
-- on the Status register
graphics.vram = memory.generate_block(8 * 1024)
memory.map_block(0x80, 0x9F, graphics.vram)
graphics.oam = memory.generate_block(0xA0)
graphics.oam.mt = {}
graphics.oam.mt.__index = function(table, address)
  -- out of range? So sorry, return nothing
  return 0x00
end
graphics.oam.mt.__newindex = function(table, address, byte)
  -- out of range? So sorry, discard the write
  return
end
setmetatable(graphics.oam, graphics.oam.mt)
memory.map_block(0xFE, 0xFE, graphics.oam)

graphics.initialize = function()
  graphics.Status.SetMode(2)
  graphics.clear_screen()
end

graphics.reset = function()
  -- zero out all of VRAM:
  for i = 0, #graphics.vram do
    graphics.vram[i] = 0
  end

  for i = 0, #graphics.oam do
    graphics.oam[i] = 0
  end

  graphics.vblank_count = 0
  graphics.last_edge = 0

  graphics.clear_screen()
  graphics.Status.SetMode(2)
end

graphics.save_state = function()
  local state = {}

  state.vram = {}
  for i = 0, #graphics.vram do
    state.vram[i] = graphics.vram[i]
  end

  state.oam = {}
  for i = 0, #graphics.oam do
    state.oam[i] = graphics.oam[i]
  end

  state.vblank_count = graphics.vblank_count
  state.last_edge = graphics.last_edge

  -- TODO: Do we bother to save the screen?
  return state
end

graphics.load_state = function(state)
  for i = 0, #graphics.vram do
    graphics.vram[i] = state.vram[i]
  end
  for i = 0, #graphics.oam do
    graphics.oam[i] = state.oam[i]
  end
  graphics.vblank_count = state.vblank_count
  graphics.last_edge = state.last_edge
end

local LCD_Control = {}
graphics.LCD_Control = LCD_Control
LCD_Control.DisplayEnabled = function()
  return bit32.band(0x80, io.ram[ports.LCDC]) ~= 0
end

LCD_Control.WindowTilemap = function()
  if bit32.band(0x40, io.ram[ports.LCDC]) ~= 0 then
    return 0x9C00
  else
    return 0x9800
  end
end

LCD_Control.WindowEnabled = function()
  return bit32.band(0x20, io.ram[ports.LCDC]) ~= 0
end

LCD_Control.TileData = function()
  if bit32.band(0x10, io.ram[ports.LCDC]) ~= 0 then
    return 0x8000
  else
    return 0x9000
  end
end

LCD_Control.BackgroundTilemap = function()
  if bit32.band(0x08, io.ram[ports.LCDC]) ~= 0 then
    return 0x9C00
  else
    return 0x9800
  end
end

LCD_Control.LargeSprites = function()
  return bit32.band(0x04, io.ram[ports.LCDC]) ~= 0
end

LCD_Control.SpritesEnabled = function()
  return bit32.band(0x02, io.ram[ports.LCDC]) ~= 0
end

LCD_Control.BackgroundEnabled = function()
  return bit32.band(0x01, io.ram[ports.LCDC]) ~= 0
end

local Status = {}
graphics.Status = Status
Status.Coincidence_InterruptEnabled = function()
  return bit32.band(0x20, io.ram[ports.STAT]) ~= 0
end

Status.OAM_InterruptEnabled = function()
  return bit32.band(0x10, io.ram[ports.STAT]) ~= 0
end

Status.VBlank_InterruptEnabled = function()
  return bit32.band(0x08, io.ram[ports.STAT]) ~= 0
end

Status.HBlank_InterruptEnabled = function()
  return bit32.band(0x06, io.ram[ports.STAT]) ~= 0
end

Status.Mode = function()
  return bit32.band(0x03, io.ram[ports.STAT])
end

Status.SetMode = function(mode)
  io.ram[ports.STAT] = bit32.band(io.ram[ports.STAT], 0xF8) + bit32.band(mode, 0x3)
  if mode == 0 then
    -- HBlank
    graphics.draw_scanline(graphics.scanline())
  end
  if mode == 1 then
    if LCD_Control.DisplayEnabled() then
      -- VBlank
      --draw_screen()
      graphics.vblank_count = graphics.vblank_count + 1
    else
      --clear_screen()
    end
  end
end

local SCY = function()
  return io.ram[ports.SCY]
end

local SCX = function()
  return io.ram[ports.SCX]
end

local WY = function()
  return io.ram[ports.WY]
end

local WX = function()
  return io.ram[ports.WX]
end

graphics.scanline = function()
  return io.ram[ports.LY]
end

graphics.set_scanline = function(value)
  io.ram[ports.LY] = value
end

graphics.scanline_compare = function()
  return io.ram[ports.LYC]
end

local time_at_this_mode = function()
  return timers.system_clock - graphics.last_edge
end

-- HBlank: Period between scanlines
local handle_mode = {}
handle_mode[0] = function()
  if timers.system_clock - graphics.last_edge > 204 then
    graphics.last_edge = graphics.last_edge + 204
    graphics.set_scanline(graphics.scanline() + 1)
    -- If enabled, fire an HBlank interrupt
    if bit32.band(io.ram[ports.STAT], 0x08) ~= 0 then
      request_interrupt(interrupts.LCDStat)
    end
    if graphics.scanline() == graphics.scanline_compare() then
      -- set the LY compare bit
      io.ram[ports.STAT] = bit32.bor(io.ram[ports.STAT], 0x4)
      if bit32.band(io.ram[ports.STAT], 0x40) ~= 0 then
        request_interrupt(interrupts.LCDStat)
      end
    else
      -- clear the LY compare bit
      io.ram[ports.STAT] = bit32.band(io.ram[ports.STAT], 0xFB)
    end
    if graphics.scanline() >= 144 then
      Status.SetMode(1)
      request_interrupt(interrupts.VBlank)
      if bit32.band(io.ram[ports.STAT], 0x10) ~= 0 then
        -- This is weird; LCDStat mirrors VBlank?
        request_interrupt(interrupts.LCDStat)
      end
      -- TODO: Draw the real screen here?
    else
      Status.SetMode(2)
      if bit32.band(io.ram[ports.STAT], 0x20) ~= 0 then
        request_interrupt(interrupts.LCDStat)
      end
    end
  end
end

--VBlank: nothing to do except wait for the next frame
handle_mode[1] = function()
  if timers.system_clock - graphics.last_edge > 456 then
    graphics.last_edge = graphics.last_edge + 456
    graphics.set_scanline(graphics.scanline() + 1)
  end
  if graphics.scanline() >= 154 then
    graphics.set_scanline(0)
    Status.SetMode(2)
    if bit32.band(io.ram[ports.STAT], 0x20) ~= 0 then
      request_interrupt(interrupts.LCDStat)
    end
  end
  if graphics.scanline() == graphics.scanline_compare() then
    -- TODO: fire LCD STAT interrupt, and set appropriate flag
  end
end

-- OAM Read: OAM cannot be accessed
handle_mode[2] = function()
  if timers.system_clock - graphics.last_edge > 80 then
    graphics.last_edge = graphics.last_edge + 80
    Status.SetMode(3)
  end
end
-- VRAM Read: Neither VRAM, OAM, nor CGB palettes can be read
handle_mode[3] = function()
  if timers.system_clock - graphics.last_edge > 172 then
    graphics.last_edge = graphics.last_edge + 172
    Status.SetMode(0)
    -- TODO: Fire HBlank interrupt here!!
    -- TODO: Draw one scanline of graphics here!
  end
end

graphics.update = function()
  if LCD_Control.DisplayEnabled() then
    handle_mode[Status.Mode()]()
  else
    -- erase our clock debt, so we don't do stupid timing things when the
    -- display is enabled again later
    graphics.last_edge = timers.system_clock
  end
end

-- TODO: Handle proper color palettes?
local colors = {}
colors[0] = {255, 255, 255}
colors[1] = {192, 192, 192}
colors[2] = {128, 128, 128}
colors[3] = {0, 0, 0}

local function plot_pixel(buffer, x, y, r, g, b)
  buffer[y][x][1] = r
  buffer[y][x][2] = g
  buffer[y][x][3] = b
end

local function debug_draw_screen()
  for i = 0, 143 do
    graphics.draw_scanline(i)
  end
end

graphics.getColorFromIndex = function(index, palette)
  palette = palette or 0xE4
  while index > 0 do
    palette = bit32.rshift(palette, 2)
    index = index - 1
  end
  return colors[bit32.band(palette, 0x3)]
end

graphics.getIndexFromTile = function(tile_address, subpixel_x, subpixel_y)
  -- move to the row we need this pixel from
  while subpixel_y > 0 do
    tile_address = tile_address + 2
    subpixel_y = subpixel_y - 1
  end
  -- grab the pixel color we need, and translate it into a palette index
  local palette_index = 0
  if bit32.band(graphics.vram[tile_address - 0x8000], bit32.lshift(0x1, 7 - subpixel_x)) ~= 0 then
    palette_index = palette_index + 1
  end
  tile_address = tile_address + 1
  if bit32.band(graphics.vram[tile_address - 0x8000], bit32.lshift(0x1, 7 - subpixel_x)) ~= 0 then
    palette_index = palette_index + 2
  end
  -- finally, return the color from the table, based on this index
  -- todo: allow specifying the palette?
  return palette_index
end

graphics.getColorFromTile = function(tile_address, subpixel_x, subpixel_y, palette)
  return graphics.getColorFromIndex(graphics.getIndexFromTile(tile_address, subpixel_x, subpixel_y), palette)
end

graphics.getIndexFromTilemap = function(map_address, x, y)
  local tile_x = bit32.rshift(x, 3)
  local tile_y = bit32.rshift(y, 3)
  local tile_index = graphics.vram[(map_address + (tile_y * 32) + (tile_x)) - 0x8000]
  if tile_index == nil then
    print(tile_x)
    print(tile_y)
    print(map_address)
    print((map_address + (tile_y * 32) + (tile_x)) - 0x8000)
  end
  if LCD_Control.TileData() == 0x9000 then
    if tile_index > 127 then
      tile_index = tile_index - 256
    end
  end
  local tile_address = LCD_Control.TileData() + tile_index * 16

  local subpixel_x = x - (tile_x * 8)
  local subpixel_y = y - (tile_y * 8)

  return graphics.getIndexFromTile(tile_address, subpixel_x, subpixel_y)
end

graphics.getColorFromTilemap = function(map_address, x, y)
  local index = graphics.getIndexFromTilemap(map_address, x, y)
  return graphics.getColorFromIndex(index, io.ram[ports.BGP])
end

-- local oam = 0xFE00

local function draw_sprites_into_scanline(scanline, bg_index)
  local active_sprites = {}
  local sprite_size = 8
  if LCD_Control.LargeSprites() then
    sprite_size = 16
  end

  -- Collect up to the 10 highest priority sprites in a list.
  -- Sprites have priority first by their X coordinate, then by their index
  -- in the list.
  local i = 0
  while i < 40 do
    -- is this sprite being displayed on this scanline? (respect to Y coordinate)
    local sprite_y = graphics.oam[i * 4]
    local sprite_lower = sprite_y - 16
    local sprite_upper = sprite_y - 16 + sprite_size
    if scanline >= sprite_lower and scanline < sprite_upper then
      if #active_sprites < 10 then
        table.insert(active_sprites, i)
      else
        -- There are more than 10 sprites in the table, so we need to pick
        -- a candidate to vote off the island (possibly this one)
        local lowest_priority = i
        local lowest_priotity_index = nil
        for j = 1, #active_sprites do
          local lowest_x = graphics.oam[lowest_priority * 4 + 1]
          local candidate_x = graphics.oam[active_sprites[j] * 4 + 1]
          if candidate_x > lowest_x then
            lowest_priority = active_sprites[j]
            lowest_priority_index = j
          end
        end
        if lowest_priority_index then
          active_sprites[lowest_priority_index] = i
        end
      end
    end
    i = i + 1
  end

  -- now, for every sprite in the list, display it on the current scanline
  for i = #active_sprites, 1, -1 do
    local sprite_address = active_sprites[i] * 4
    local sprite_y = graphics.oam[sprite_address]
    local sprite_x = graphics.oam[sprite_address + 1]
    local sprite_tile = graphics.oam[sprite_address + 2]
    if sprite_size == 16 then
      sprite_tile = bit32.band(sprite_tile, 0xFE)
    end
    local sprite_flags = graphics.oam[sprite_address + 3]

    local y_flipped = bit32.band(0x40, sprite_flags) ~= 0
    local x_flipped = bit32.band(0x20, sprite_flags) ~= 0

    local sub_y = 16 - (sprite_y - scanline)
    if y_flipped then
      sub_y = sprite_size - 1 - sub_y
    end

    local sprite_bg_priority = (bit32.band(0x80, sprite_flags) == 0)

    local sprite_palette = io.ram[ports.OBP0]
    if bit32.band(sprite_flags, 0x10) ~= 0 then
      sprite_palette = io.ram[ports.OBP1]
    end

    for x = 0, 7 do
      local display_x = sprite_x - 8 + x
      if display_x >= 0 and display_x < 160 then
        local sub_x = x
        if x_flipped then
          sub_x = 7 - x
        end
        local subpixel_index = graphics.getIndexFromTile(0x8000 + sprite_tile * 16, sub_x, sub_y, sprite_palette)
        if subpixel_index > 0 then
          if sprite_bg_priority or bg_index[display_x] == 0 then
            local subpixel_color = graphics.getColorFromIndex(subpixel_index, sprite_palette)
            plot_pixel(graphics.game_screen, display_x, scanline, unpack(subpixel_color))
          end
        end
      end
    end
  end
  if #active_sprites > 0 then
  end
end

graphics.draw_scanline = function(scanline)
  local bg_y = scanline + SCY()
  local bg_x = SCX()
  -- wrap the map in the Y direction
  if bg_y >= 256 then
    bg_y = bg_y - 256
  end

  local scanline_bg_index = {}

  local w_x = WX() - 7
  for x = 0, 159 do
    scanline_bg_index[x] = 0
    if w_x <= x and WY() <= scanline and LCD_Control.WindowEnabled() then
      -- The Window is visible here, so draw that
      local window_index = graphics.getIndexFromTilemap(LCD_Control.WindowTilemap(), x - w_x, scanline - WY())
      scanline_bg_index[x] = window_index
      plot_pixel(graphics.game_screen, x, scanline, unpack(graphics.getColorFromIndex(window_index, io.ram[ports.BGP])))
    else
      -- The background is visible
      if LCD_Control.BackgroundEnabled() then
        local bg_index = graphics.getIndexFromTilemap(LCD_Control.BackgroundTilemap(), bg_x, bg_y)
        scanline_bg_index[x] = bg_index
        plot_pixel(graphics.game_screen, x, scanline, unpack(graphics.getColorFromIndex(bg_index, io.ram[ports.BGP])))
      end
    end
    bg_x = bg_x + 1
    if bg_x >= 256 then
      bg_x = bg_x - 256
    end
  end

  draw_sprites_into_scanline(scanline, scanline_bg_index)
end

return graphics
