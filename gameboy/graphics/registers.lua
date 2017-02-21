local bit32 = require("bit")
local io = require("gameboy/io")
local cache = require("gameboy/graphics/cache")
local ports = io.ports

local registers = {}

registers.display_enabled = true
registers.window_tilemap = cache.map_0
registers.window_enabled = true
registers.tile_select = 0x8800
registers.background_tilemap = cache.map_0
registers.large_sprites = false
registers.sprites_enabled = true
registers.background_enabled = true


local LCD_Control = {}
registers.LCD_Control = LCD_Control

io.write_logic[ports.LCDC] = function(byte)
  io.ram[ports.LCDC] = byte

  -- Unpack all the bit flags into lua variables, for great sanity
  registers.display_enabled = bit32.band(0x80, byte) ~= 0
  registers.window_enabled  = bit32.band(0x20, byte) ~= 0
  registers.large_sprites   = bit32.band(0x04, byte) ~= 0
  registers.sprites_enabled = bit32.band(0x02, byte) ~= 0
  registers.background_enabled      = bit32.band(0x01, byte) ~= 0

  if bit32.band(0x40, byte) ~= 0 then
    registers.window_tilemap = cache.map_1
  else
    registers.window_tilemap = cache.map_0
  end

  if bit32.band(0x10, byte) ~= 0 then
    registers.tile_select = 0x8000
  else
    registers.tile_select = 0x8800
  end

  if bit32.band(0x08, byte) ~= 0 then
    registers.background_tilemap = cache.map_1
  else
    registers.background_tilemap = cache.map_0
  end
end

LCD_Control.TileData = function()
  if bit32.band(0x10, io.ram[ports.LCDC]) ~= 0 then
    return 0x8000
  else
    return 0x9000
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
