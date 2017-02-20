local io = require("gameboy/io")

local registers = {}

local LCD_Control = {}
registers.LCD_Control = LCD_Control
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
