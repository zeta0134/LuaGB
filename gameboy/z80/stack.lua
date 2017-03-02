local bit32 = require("bit")

local band = bit32.band
local lshift = bit32.lshift
local rshift = bit32.rshift

function apply(opcodes, opcode_cycles, z80, memory)
  local reg = z80.registers

  local read_byte = memory.read_byte
  local write_byte = memory.write_byte

  -- push BC
  opcode_cycles[0xC5] = 16
  opcodes[0xC5] = function()
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.b)
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.c)
  end

  -- push DE
  opcode_cycles[0xD5] = 16
  opcodes[0xD5] = function()
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.d)
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.e)
  end

  -- push HL
  opcode_cycles[0xE5] = 16
  opcodes[0xE5] = function()
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.h)
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.l)
  end

  -- push AF
  opcode_cycles[0xF5] = 16
  opcodes[0xF5] = function()
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.a)
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.f())
  end

  -- pop BC
  opcode_cycles[0xC1] = 12
  opcodes[0xC1] = function()
    reg.c = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
    reg.b = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
  end

  -- pop DE
  opcode_cycles[0xD1] = 12
  opcodes[0xD1] = function()
    reg.e = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
    reg.d = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
  end

  -- pop HL
  opcode_cycles[0xE1] = 12
  opcodes[0xE1] = function()
    reg.l = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
    reg.h = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
  end

  -- pop AF
  opcode_cycles[0xF1] = 12
  opcodes[0xF1] = function()
    reg.set_f(read_byte(reg.sp))
    reg.sp = band(0xFFFF, reg.sp + 1)
    reg.a = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
  end
end

return apply
