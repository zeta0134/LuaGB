local bit32 = require("bit")

local lshift = bit32.lshift
local band = bit32.band
local rshift = bit32.rshift

local Registers = {}

function Registers.new()
  local registers = {}
  local reg = registers

  reg.a = 0
  reg.b = 0
  reg.c = 0
  reg.d = 0
  reg.e = 0
  reg.flags = {z=false,n=false,h=false,c=false}
  reg.h = 0
  reg.l = 0
  reg.pc = 0
  reg.sp = 0

  reg.f = function()
    local value = 0
    if reg.flags.z then
      value = value + 0x80
    end
    if reg.flags.n then
      value = value + 0x40
    end
    if reg.flags.h then
      value = value + 0x20
    end
    if reg.flags.c then
      value = value + 0x10
    end
    return value
  end

  reg.set_f = function(value)
    reg.flags.z = band(value, 0x80) ~= 0
    reg.flags.n = band(value, 0x40) ~= 0
    reg.flags.h = band(value, 0x20) ~= 0
    reg.flags.c = band(value, 0x10) ~= 0
  end

  reg.af = function()
    return lshift(reg.a, 8) + reg.f()
  end

  reg.bc = function()
    return lshift(reg.b, 8) + reg.c
  end

  reg.de = function()
    return lshift(reg.d, 8) + reg.e
  end

  reg.hl = function()
    return lshift(reg.h, 8) + reg.l
  end

  reg.set_bc = function(value)
    reg.b = rshift(band(value, 0xFF00), 8)
    reg.c = band(value, 0xFF)
  end

  reg.set_de = function(value)
    reg.d = rshift(band(value, 0xFF00), 8)
    reg.e = band(value, 0xFF)
  end

  reg.set_hl = function(value)
    reg.h = rshift(band(value, 0xFF00), 8)
    reg.l = band(value, 0xFF)
  end

  return registers
end

return Registers
