local bit32 = require("bit")

local Cache = require("gameboy/graphics/cache")
local Palette = require("gameboy/graphics/palette")
local Registers = require("gameboy/graphics/registers")

local Graphics = {}

function Graphics.new(modules)
  local interrupts = modules.interrupts
  local io = modules.io
  local memory = modules.memory
  local timers = modules.timers

  local graphics = {}

  graphics.cache = Cache.new()
  graphics.palette = Palette.new(modules)
  graphics.registers = Registers.new(modules, graphics.cache)

  graphics.cache.graphics = graphics

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

  graphics.lcd = {}

  -- Initialize VRAM blocks in main memory
  graphics.vram = memory.generate_block(16 * 2 * 1024, 0x8000)
  graphics.vram.bank = 0
  graphics.vram_map = {}
  graphics.vram_map.mt = {}
  graphics.vram_map.mt.__index = function(table, address)
    return graphics.vram[address + (16 * 1024 * graphics.vram.bank)]
  end
  graphics.vram_map.mt.__newindex = function(table, address, value)
    graphics.vram[address + (16 * 1024 * graphics.vram.bank)] = value
    if address >= 0x8000 and address <= 0x97FF then
      graphics.cache.refreshTile(address, graphics.vram.bank)
    end
    if address >= 0x9800 and address <= 0x9BFF then
      local x = address % 32
      local y = math.floor((address - 0x9800) / 32)
      if graphics.vram.bank == 1 then
        graphics.cache.refreshAttributes(graphics.cache.map_0_attr, x, y, address)
      end
      graphics.cache.refreshTileIndex(x, y, 0x9800, graphics.cache.map_0, graphics.cache.map_0_attr)
    end
    if address >= 0x9C00 and address <= 0x9FFF then
      local x = address % 32
      local y = math.floor((address - 0x9C00) / 32)
      if graphics.vram.bank == 1 then
        graphics.cache.refreshAttributes(graphics.cache.map_1_attr, x, y, address)
      end
      graphics.cache.refreshTileIndex(x, y, 0x9C00, graphics.cache.map_1, graphics.cache.map_1_attr)
    end
  end
  setmetatable(graphics.vram_map, graphics.vram_map.mt)
  memory.map_block(0x80, 0x9F, graphics.vram_map, 0)

  graphics.oam = memory.generate_block(0xA0, 0xFE00)
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
  memory.map_block(0xFE, 0xFE, graphics.oam, 0)

  io.write_logic[0x4F] = function(byte)
    if graphics.gameboy.type == graphics.gameboy.types.color then
      io.ram[0x4F] = bit32.band(0x1, byte)
      graphics.vram.bank = bit32.band(0x1, byte)
    else
      -- Not sure if the write mask should apply in DMG / SGB mode
      io.ram[0x4F] = byte
    end
  end

  graphics.initialize = function(gameboy)
    graphics.gameboy = gameboy
    graphics.registers.Status.SetMode(2)
    graphics.clear_screen()
    graphics.reset()
  end

  graphics.reset = function()
    -- zero out all of VRAM:
    for i = 0x8000, 0x9FFF do
      graphics.vram[i] = 0
    end

    -- zero out all of OAM
    for i = 0xFE00, 0xFE9F do
      graphics.oam[i] = 0
    end

    graphics.vblank_count = 0
    graphics.last_edge = 0
    graphics.vram.bank = 0

    graphics.clear_screen()
    graphics.registers.Status.SetMode(2)

    graphics.cache.reset()
    graphics.palette.reset()
  end

  graphics.save_state = function()
    local state = {}

    state.vram = {}
    for i = 0x8000, 0x9FFF do
      state.vram[i] = graphics.vram[i]
    end

    state.oam = {}
    for i = 0xFE00, 0xFE9F do
      state.oam[i] = graphics.oam[i]
    end

    state.vblank_count = graphics.vblank_count
    state.last_edge = graphics.last_edge

    state.palette = {}
    state.palette.bg   = graphics.palette.bg
    state.palette.obj0 = graphics.palette.obj0
    state.palette.obj1 = graphics.palette.obj1

    return state
  end

  graphics.load_state = function(state)
    for i = 0x8000, 0x9FFF do
      graphics.vram[i] = state.vram[i]
    end
    for i = 0xFE00, 0xFE9F do
      graphics.oam[i] = state.oam[i]
    end
    graphics.vblank_count = state.vblank_count
    graphics.last_edge = state.last_edge

    graphics.cache.reset()
    graphics.cache.refreshAll()

    graphics.palette.bg   = state.palette.bg
    graphics.palette.obj0 = state.palette.obj0
    graphics.palette.obj1 = state.palette.obj1
  end

  local time_at_this_mode = function()
    return timers.system_clock - graphics.last_edge
  end

  local scanline_data = {}
  scanline_data.x = 0
  scanline_data.bg_tile_x = 0
  scanline_data.bg_tile_y = 0
  scanline_data.sub_x = 0
  scanline_data.sub_y = 0
  scanline_data.active_tile = nil
  scanline_data.active_attr = nil
  scanline_data.current_map = nil
  scanline_data.current_map_attr = nil
  scanline_data.window_active = false
  scanline_data.bg_index = {}
  scanline_data.active_palette = nil

  -- HBlank: Period between scanlines
  local handle_mode = {}
  handle_mode[0] = function()
    if timers.system_clock - graphics.last_edge > 204 then
      graphics.last_edge = graphics.last_edge + 204
      io.ram[ports.LY] = io.ram[ports.LY] + 1
      -- If enabled, fire an HBlank interrupt
      if bit32.band(io.ram[ports.STAT], 0x08) ~= 0 then
        request_interrupt(interrupts.LCDStat)
      end
      if io.ram[ports.LY] == io.ram[ports.LYC] then
        -- set the LY compare bit
        io.ram[ports.STAT] = bit32.bor(io.ram[ports.STAT], 0x4)
        if bit32.band(io.ram[ports.STAT], 0x40) ~= 0 then
          request_interrupt(interrupts.LCDStat)
        end
      else
        -- clear the LY compare bit
        io.ram[ports.STAT] = bit32.band(io.ram[ports.STAT], 0xFB)
      end
      if io.ram[ports.LY] >= 144 then
        graphics.registers.Status.SetMode(1)
        graphics.vblank_count = graphics.vblank_count + 1
        request_interrupt(interrupts.VBlank)
        if bit32.band(io.ram[ports.STAT], 0x10) ~= 0 then
          -- This is weird; LCDStat mirrors VBlank?
          request_interrupt(interrupts.LCDStat)
        end
      else
        graphics.registers.Status.SetMode(2)
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
      io.ram[ports.LY] = io.ram[ports.LY] + 1
    end
    if io.ram[ports.LY] >= 154 then
      io.ram[ports.LY] = 0
      graphics.initialize_frame()
      graphics.registers.Status.SetMode(2)
      if bit32.band(io.ram[ports.STAT], 0x20) ~= 0 then
        request_interrupt(interrupts.LCDStat)
      end
    end
    if io.ram[ports.LY] == io.ram[ports.LYC] then
      -- set the LY compare bit
      io.ram[ports.STAT] = bit32.bor(io.ram[ports.STAT], 0x4)
      if bit32.band(io.ram[ports.STAT], 0x40) ~= 0 then
        request_interrupt(interrupts.LCDStat)
      end
    else
      -- clear the LY compare bit
      io.ram[ports.STAT] = bit32.band(io.ram[ports.STAT], 0xFB)
    end
  end

  -- OAM Read: OAM cannot be accessed
  handle_mode[2] = function()
    if timers.system_clock - graphics.last_edge > 80 then
      graphics.last_edge = graphics.last_edge + 80
      graphics.initialize_scanline()
      graphics.registers.Status.SetMode(3)
    end
  end
  -- VRAM Read: Neither VRAM, OAM, nor CGB palettes can be read
  handle_mode[3] = function()
    local duration = timers.system_clock - graphics.last_edge
    graphics.draw_next_pixels(duration)
    if timers.system_clock - graphics.last_edge > 172 then
      graphics.last_edge = graphics.last_edge + 172
      graphics.draw_sprites_into_scanline(io.ram[ports.LY], scanline_data.bg_index)
      graphics.registers.Status.SetMode(0)
    end
  end

  graphics.update = function()
    if graphics.registers.display_enabled then
      handle_mode[graphics.registers.Status.Mode()]()
    else
      -- erase our clock debt, so we don't do stupid timing things when the
      -- display is enabled again later
      graphics.last_edge = timers.system_clock
      graphics.registers.Status.SetMode(0)
      io.ram[ports.LY] = 0
    end
  end

  local function plot_pixel(buffer, x, y, r, g, b)
    buffer[y][x][1] = r
    buffer[y][x][2] = g
    buffer[y][x][3] = b
  end

  local frame_data = {}
  frame_data.window_y = 0

  graphics.initialize_frame = function()
    -- latch WY at the beginning of the *frame*
    frame_data.window_y = io.ram[ports.WY]
  end

  graphics.initialize_scanline = function()
    scanline_data.x = 0

    scanline_data.bg_tile_x = math.floor(io.ram[ports.SCX] / 8)
    scanline_data.bg_tile_y = math.floor((io.ram[ports.LY] + io.ram[ports.SCY]) / 8)
    if scanline_data.bg_tile_y >= 32 then
      scanline_data.bg_tile_y = scanline_data.bg_tile_y - 32
    end

    scanline_data.sub_x = io.ram[ports.SCX] % 8
    scanline_data.sub_y = (io.ram[ports.LY] + io.ram[ports.SCY]) % 8

    scanline_data.current_map = graphics.registers.background_tilemap
    scanline_data.current_map_attr = graphics.registers.background_attr

    scanline_data.active_attr = scanline_data.current_map_attr[scanline_data.bg_tile_x][scanline_data.bg_tile_y]
    scanline_data.active_tile = scanline_data.current_map[scanline_data.bg_tile_x][scanline_data.bg_tile_y]
  end

  graphics.switch_to_window = function()
    local ly = io.ram[ports.LY]
    local w_x = io.ram[ports.WX] - 7
    if graphics.registers.window_enabled and scanline_data.x >= w_x and ly >= frame_data.window_y then
      -- switch to window map
      scanline_data.current_map = graphics.registers.window_tilemap
      scanline_data.current_map_attr = graphics.registers.window_attr
      scanline_data.bg_tile_x = math.floor((scanline_data.x - w_x) / 8)
      scanline_data.bg_tile_y = math.floor((ly - frame_data.window_y) / 8)
      scanline_data.sub_x = (scanline_data.x - (io.ram[ports.WX] - 7)) % 8
      scanline_data.sub_y = (ly - io.ram[ports.WY]) % 8

      scanline_data.active_attr = scanline_data.current_map_attr[scanline_data.bg_tile_x][scanline_data.bg_tile_y]
      scanline_data.active_tile = scanline_data.current_map[scanline_data.bg_tile_x][scanline_data.bg_tile_y]
    end
  end

  graphics.draw_next_pixels = function(duration)
    local ly = io.ram[ports.LY]

    while scanline_data.x < duration and scanline_data.x < 160 do
      if not scanline_data.window_active then
        graphics.switch_to_window()
      end

      local bg_index = 0 --default, in case no background is enabled
      if graphics.registers.background_enabled then
        -- DRAW BG PIXEL HERE
        local sub_x = scanline_data.sub_x
        local sub_y = scanline_data.sub_y
        bg_index = scanline_data.active_tile[sub_x][sub_y]
        plot_pixel(graphics.game_screen, scanline_data.x, ly, unpack(scanline_data.active_attr.palette[bg_index]))
      end

      scanline_data.bg_index[scanline_data.x] = bg_index

      --if graphics.registers.sprites_enabled then
        -- DRAW OAM PIXEL HERE
      --end

      scanline_data.x = scanline_data.x  + 1
      scanline_data.sub_x = scanline_data.sub_x  + 1
      if scanline_data.sub_x > 7 then
        -- fetch next tile
        scanline_data.sub_x = 0
        scanline_data.bg_tile_x = scanline_data.bg_tile_x + 1
        if scanline_data.bg_tile_x >= 32 then
          scanline_data.bg_tile_x = scanline_data.bg_tile_x - 32
        end
        scanline_data.sub_y = (ly + io.ram[ports.SCY]) % 8
        scanline_data.bg_tile_y = math.floor((ly + io.ram[ports.SCY]) / 8)
        if scanline_data.bg_tile_y >= 32 then
          scanline_data.bg_tile_y = scanline_data.bg_tile_y - 32
        end

        local tile_attr = scanline_data.current_map_attr[scanline_data.bg_tile_x][scanline_data.bg_tile_y]
        if tile_attr.vertical_flip then
          scanline_data.sub_y = 7 - scanline_data.sub_y
        end

        scanline_data.active_attr = scanline_data.current_map_attr[scanline_data.bg_tile_x][scanline_data.bg_tile_y]
        scanline_data.active_tile = scanline_data.current_map[scanline_data.bg_tile_x][scanline_data.bg_tile_y]
      end
    end
  end

  graphics.getIndexFromTilemap = function(map, tile_data, x, y)
    local tile_x = bit32.rshift(x, 3)
    local tile_y = bit32.rshift(y, 3)
    local tile_index = map[tile_x][tile_y]

    local subpixel_x = x - (tile_x * 8)
    local subpixel_y = y - (tile_y * 8)

    if tile_data == 0x9000 then
      if tile_index > 127 then
        tile_index = tile_index - 256
      end
      -- add offset to re-root at tile 256 (so effectively, we read from tile 192 - 384)
      tile_index = tile_index + 256
    end

    if graphics.gameboy.type == graphics.gameboy.types.color then
      local map_attr = graphics.cache.map_0_attr
      if map == graphics.cache.map_1 then
        map_attr = graphics.cache.map_1_attr
      end
      local tile_attributes = map_attr[tile_x][tile_y]
      tile_index = tile_index + tile_attributes.bank * 384

      if tile_attributes.horizontal_flip == true then
        subpixel_x = (7 - subpixel_x)
      end

      if tile_attributes.vertical_flip == true then
        subpixel_y = (7 - subpixel_y)
      end
    end

    return graphics.cache.tiles[tile_index][subpixel_x][subpixel_y]
  end

  graphics.draw_sprites_into_scanline = function(scanline, bg_index)
    if not graphics.registers.sprites_enabled then
      return
    end
    local active_sprites = {}
    local sprite_size = 8
    if graphics.registers.large_sprites then
      sprite_size = 16
    end

    -- Collect up to the 10 highest priority sprites in a list.
    -- Sprites have priority first by their X coordinate, then by their index
    -- in the list.
    local i = 0
    while i < 40 do
      -- is this sprite being displayed on this scanline? (respect to Y coordinate)
      local sprite_y = graphics.oam[0xFE00 + i * 4]
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
            local lowest_x = graphics.oam[0xFE00 + lowest_priority * 4 + 1]
            local candidate_x = graphics.oam[0xFE00 + active_sprites[j] * 4 + 1]
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
      local sprite_address = 0xFE00 + active_sprites[i] * 4
      local sprite_y = graphics.oam[sprite_address]
      local sprite_x = graphics.oam[sprite_address + 1]
      local sprite_tile = graphics.oam[sprite_address + 2]
      if sprite_size == 16 then
        sprite_tile = bit32.band(sprite_tile, 0xFE)
      end
      local sprite_flags = graphics.oam[sprite_address + 3]

      local y_flipped = bit32.band(0x40, sprite_flags) ~= 0
      local x_flipped = bit32.band(0x20, sprite_flags) ~= 0

      local sprite_palette = graphics.palette.obj0
      if bit32.band(sprite_flags, 0x10) ~= 0 then
        sprite_palette = graphics.palette.obj1
      end

      -- handle color mode vram bank
      if graphics.gameboy.type == graphics.gameboy.types.color then
        if bit32.band(0x08, sprite_flags) ~= 0 then
          sprite_tile = sprite_tile + 384
        end

        local sprite_palette_index = bit32.band(0x07, sprite_flags)
        sprite_palette = graphics.palette.color_obj[sprite_palette_index]
      end

      local sub_y = 16 - (sprite_y - scanline)
      if y_flipped then
        sub_y = sprite_size - 1 - sub_y
      end

      local sprite_bg_priority = (bit32.band(0x80, sprite_flags) == 0)

      if sub_y >= 8 then
        sprite_tile = sprite_tile + 1
        sub_y = sub_y - 8
      end

      local tile = graphics.cache.tiles[sprite_tile]

      for x = 0, 7 do
        local display_x = sprite_x - 8 + x
        if display_x >= 0 and display_x < 160 then
          local sub_x = x
          if x_flipped then
            sub_x = 7 - x
          end
          local subpixel_index = tile[sub_x][sub_y]
          if subpixel_index > 0 then
            if sprite_bg_priority or bg_index[display_x] == 0 then
              local subpixel_color = sprite_palette[subpixel_index]
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
    if scanline < 0 or scanline > 143 then
      print("Bad scanline: ", scanline)
      return
    end
    local bg_y = scanline + io.ram[ports.SCY]
    local bg_x = io.ram[ports.SCX]
    -- wrap the map in the Y direction
    if bg_y >= 256 then
      bg_y = bg_y - 256
    end

    local scanline_bg_index = {}

    -- Grab this stuff just once, rather than every iteration
    -- through the loop
    local tile_data = graphics.registers.tile_select
    local window_tilemap = graphics.registers.window_tilemap
    local background_tilemap = graphics.registers.background_tilemap
    local window_enabled = graphics.registers.window_enabled
    local background_enabled = graphics.registers.background_enabled

    local w_x = io.ram[ports.WX] - 7
    local w_y = io.ram[ports.WY]

    for x = 0, 159 do
      scanline_bg_index[x] = 0
      if window_enabled and w_x <= x and w_y <= scanline then
        -- The Window is visible here, so draw that
        local window_index = graphics.getIndexFromTilemap(window_tilemap, tile_data, x - w_x, scanline - w_y)
        scanline_bg_index[x] = window_index
        plot_pixel(graphics.game_screen, x, scanline, unpack(graphics.palette.bg[window_index]))
      else
        -- The background is visible
        if background_enabled then
          local bg_index = graphics.getIndexFromTilemap(background_tilemap, tile_data, bg_x, bg_y)
          scanline_bg_index[x] = bg_index
          plot_pixel(graphics.game_screen, x, scanline, unpack(graphics.palette.bg[bg_index]))
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
end

return Graphics
