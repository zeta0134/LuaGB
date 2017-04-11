local bit32 = luagb.require("bit")

local lshift = bit32.lshift
local band = bit32.band

function apply(opcodes, opcode_cycles, z80, memory)
  local read_at_hl = z80.read_at_hl
  local set_at_hl = z80.set_at_hl
  local read_nn = z80.read_nn
  local reg = z80.registers

  local read_byte = memory.read_byte
  local write_byte = memory.write_byte

  cp_with_a = function(value)
    -- half-carry
    if (reg.a % 0x10) - (value % 0x10) < 0 then
      reg.flags.h = 1
    else
      reg.flags.h = 0
    end

    local temp = reg.a - value

    -- carry (and overflow correction)
    if temp < 0 or temp > 0xFF then
      temp  = (temp + 0x100) % 0x100
      reg.flags.c = 1
    else
      reg.flags.c = 0
    end

    if temp == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end

    reg.flags.n = 1
  end

  -- cp A, r
  opcodes[0xB8] = function() cp_with_a(reg.b) end
  opcodes[0xB9] = function() cp_with_a(reg.c) end
  opcodes[0xBA] = function() cp_with_a(reg.d) end
  opcodes[0xBB] = function() cp_with_a(reg.e) end
  opcodes[0xBC] = function() cp_with_a(reg.h) end
  opcodes[0xBD] = function() cp_with_a(reg.l) end
  opcode_cycles[0xBE] = 8
  opcodes[0xBE] = function() cp_with_a(read_at_hl()) end
  opcodes[0xBF] = function() cp_with_a(reg.a) end

  -- cp A, nn
  opcode_cycles[0xFE] = 8
  opcodes[0xFE] = function() cp_with_a(read_nn()) end
end

return apply
