local bit32 = require("bit")
local io = require("gameboy/io")
local ports = io.ports

local palette = {}

local dmg_colors = {}
dmg_colors[0] = {255, 255, 255}
dmg_colors[1] = {192, 192, 192}
dmg_colors[2] = {128, 128, 128}
dmg_colors[3] = {0, 0, 0}
palette.dmg_colors = dmg_colors

palette.set_dmg_colors = function(pal_0, pal_1, pal_2, pal_3)
  dmg_colors[0] = pal_0
  dmg_colors[1] = pal_1
  dmg_colors[2] = pal_2
  dmg_colors[3] = pal_3
end

palette.bg =   {}
palette.obj0 = {}
palette.obj1 = {}
for i = 0, 3 do
  palette.bg[i] = dmg_colors[i]
  palette.obj0[i] = dmg_colors[i]
  palette.obj1[i] = dmg_colors[i]
end

local getColorFromIndex = function(index, palette)
  palette = palette or 0xE4
  while index > 0 do
    palette = bit32.rshift(palette, 2)
    index = index - 1
  end
  return dmg_colors[bit32.band(palette, 0x3)]
end

io.write_logic[ports.BGP] = function(byte)
  io.ram[ports.BGP] = byte
  for i = 0, 3 do
    palette.bg[i] = getColorFromIndex(i, byte)
  end
end

io.write_logic[ports.OBP0] = function(byte)
  io.ram[ports.OBP0] = byte
  for i = 0, 3 do
    palette.obj0[i] = getColorFromIndex(i, byte)
  end
end

io.write_logic[ports.OBP1] = function(byte)
  io.ram[ports.OBP1] = byte
  for i = 0, 3 do
    palette.obj1[i] = getColorFromIndex(i, byte)
  end
end

return palette
