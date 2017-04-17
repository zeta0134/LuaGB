local bit32 = require("bit")

local lshift = bit32.lshift
local band = bit32.band
local band = bit32.band
local bxor = bit32.bxor
local bor = bit32.bor
local bnor = bit32.bnor

function apply(opcodes, opcode_cycles, z80, memory)
  local read_at_hl = z80.read_at_hl
  local set_at_hl = z80.set_at_hl
  local read_nn = z80.read_nn
  local reg = z80.registers
  local flags = reg.flags

  local read_byte = memory.read_byte
  local write_byte = memory.write_byte

  and_a_with = function(value)
    reg.a = band(reg.a, value)
    flags.z = reg.a == 0
    flags.n = false
    flags.h = true
    flags.c = false
  end

  -- and A, r
  opcodes[0xA0] = function() and_a_with(reg.b) end
  opcodes[0xA1] = function() and_a_with(reg.c) end
  opcodes[0xA2] = function() and_a_with(reg.d) end
  opcodes[0xA3] = function() and_a_with(reg.e) end
  opcodes[0xA4] = function() and_a_with(reg.h) end
  opcodes[0xA5] = function() and_a_with(reg.l) end
  opcode_cycles[0xA6] = 8
  opcodes[0xA6] = function() and_a_with(read_at_hl()) end
  opcodes[0xA7] = function()
    --reg.a = band(reg.a, value)
    flags.z = reg.a == 0
    flags.n = false
    flags.h = true
    flags.c = false
  end

  -- and A, nn
  opcode_cycles[0xE6] = 8
  opcodes[0xE6] = function() and_a_with(read_nn()) end

  xor_a_with = function(value)
    reg.a = bxor(reg.a, value)
    flags.z = reg.a == 0
    flags.n = false
    flags.h = false
    flags.c = false
  end

  -- xor A, r
  opcodes[0xA8] = function() xor_a_with(reg.b) end
  opcodes[0xA9] = function() xor_a_with(reg.c) end
  opcodes[0xAA] = function() xor_a_with(reg.d) end
  opcodes[0xAB] = function() xor_a_with(reg.e) end
  opcodes[0xAC] = function() xor_a_with(reg.h) end
  opcodes[0xAD] = function() xor_a_with(reg.l) end
  opcode_cycles[0xAE] = 8
  opcodes[0xAE] = function() xor_a_with(read_at_hl()) end
  opcodes[0xAF] = function()
    reg.a = 0
    flags.z = true
    flags.n = false
    flags.h = false
    flags.c = false
  end

  -- xor A, nn
  opcode_cycles[0xEE] = 8
  opcodes[0xEE] = function() xor_a_with(read_nn()) end

  or_a_with = function(value)
    reg.a = bor(reg.a, value)
    flags.z = reg.a == 0
    flags.n = false
    flags.h = false
    flags.c = false
  end

  -- or A, r
  opcodes[0xB0] = function() or_a_with(reg.b) end
  opcodes[0xB1] = function() or_a_with(reg.c) end
  opcodes[0xB2] = function() or_a_with(reg.d) end
  opcodes[0xB3] = function() or_a_with(reg.e) end
  opcodes[0xB4] = function() or_a_with(reg.h) end
  opcodes[0xB5] = function() or_a_with(reg.l) end
  opcode_cycles[0xB6] = 8
  opcodes[0xB6] = function() or_a_with(read_at_hl()) end
  opcodes[0xB7] = function()
    flags.z = reg.a == 0
    flags.n = false
    flags.h = false
    flags.c = false
  end

  -- or A, nn
  opcode_cycles[0xF6] = 8
  opcodes[0xF6] = function() or_a_with(read_nn()) end

  -- cpl
  opcodes[0x2F] = function()
    reg.a = bxor(reg.a, 0xFF)
    flags.n = true
    flags.h = true
  end
end

return apply
