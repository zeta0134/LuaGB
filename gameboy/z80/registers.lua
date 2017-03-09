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
  reg.flags = {z=0,n=0,h=0,c=0}
  reg.h = 0
  reg.l = 0
  reg.pc = 0
  reg.sp = 0

  reg.f = function()
    local value = lshift(reg.flags.z, 7) +
            lshift(reg.flags.n, 6) +
            lshift(reg.flags.h, 5) +
            lshift(reg.flags.c, 4)
    return value
  end

  reg.set_f = function(value)
    if band(value, 0x80) ~= 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end

    if band(value, 0x40) ~= 0 then
      reg.flags.n = 1
    else
      reg.flags.n = 0
    end

    if band(value, 0x20) ~= 0 then
      reg.flags.h = 1
    else
      reg.flags.h = 0
    end

    if band(value, 0x10) ~= 0 then
      reg.flags.c = 1
    else
      reg.flags.c = 0
    end
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
