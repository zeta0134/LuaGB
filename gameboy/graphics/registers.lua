local bit32 = require("bit")

local Registers = {}

function Registers.new(graphics, modules, cache)
  local io = modules.io
  local ports = io.ports

  local registers = {}

  registers.display_enabled = true
  registers.window_tilemap = cache.map_0
  registers.window_attr = cache.map_0_attr
  registers.window_enabled = true
  registers.tile_select = 0x9000
  registers.background_tilemap = cache.map_0
  registers.background_attr = cache.map_0_attr
  registers.large_sprites = false
  registers.sprites_enabled = true
  registers.background_enabled = true
  registers.oam_priority = false

  io.write_logic[ports.LCDC] = function(byte)
    io.ram[ports.LCDC] = byte

    -- Unpack all the bit flags into lua variables, for great sanity
    registers.display_enabled = bit32.band(0x80, byte) ~= 0
    registers.window_enabled  = bit32.band(0x20, byte) ~= 0
    registers.large_sprites   = bit32.band(0x04, byte) ~= 0
    registers.sprites_enabled = bit32.band(0x02, byte) ~= 0

    if graphics.gameboy.type == graphics.gameboy.types.color then
      registers.oam_priority = bit32.band(0x01, byte) == 0
    else
      registers.background_enabled = bit32.band(0x01, byte) ~= 0
    end

    if bit32.band(0x40, byte) ~= 0 then
      registers.window_tilemap = cache.map_1
      registers.window_attr = cache.map_1_attr
    else
      registers.window_tilemap = cache.map_0
      registers.window_attr = cache.map_0_attr
    end

    if bit32.band(0x10, byte) ~= 0 then
      if registers.tile_select == 0x9000 then
        -- refresh our tile indices, they'll all need recalculating for the new offset
        registers.tile_select = 0x8000
        cache.refreshTileMaps()
      end
    else
      if registers.tile_select == 0x8000 then
        -- refresh our tile indices, they'll all need recalculating for the new offset
        registers.tile_select = 0x9000
        cache.refreshTileMaps()
      end
    end

    if bit32.band(0x08, byte) ~= 0 then
      registers.background_tilemap = cache.map_1
      registers.background_attr = cache.map_1_attr
    else
      registers.background_tilemap = cache.map_0
      registers.background_attr = cache.map_0_attr
    end
  end

  local Status = {}
  registers.Status = Status
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
    io.ram[ports.STAT] = bit32.band(io.ram[ports.STAT], 0xFC) + bit32.band(mode, 0x3)
  end

  return registers
end

return Registers
