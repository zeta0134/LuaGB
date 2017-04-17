local bit32 = require("bit")

local lshift = bit32.lshift
local band = bit32.band

function apply(opcodes, opcode_cycles, z80, memory)
  local reg = z80.registers
  local flags = reg.flags

  local read_byte = memory.read_byte
  local write_byte = memory.write_byte

  set_inc_flags = function(value)
    flags.z = value == 0
    flags.h = value % 0x10 == 0x0
    flags.n = false
  end

  set_dec_flags = function(value)
    flags.z = value == 0
    flags.h = value % 0x10 == 0xF
    flags.n = true
  end

  -- inc r
  opcodes[0x04] = function() reg.b = band(reg.b + 1, 0xFF); set_inc_flags(reg.b) end
  opcodes[0x0C] = function() reg.c = band(reg.c + 1, 0xFF); set_inc_flags(reg.c) end
  opcodes[0x14] = function() reg.d = band(reg.d + 1, 0xFF); set_inc_flags(reg.d) end
  opcodes[0x1C] = function() reg.e = band(reg.e + 1, 0xFF); set_inc_flags(reg.e) end
  opcodes[0x24] = function() reg.h = band(reg.h + 1, 0xFF); set_inc_flags(reg.h) end
  opcodes[0x2C] = function() reg.l = band(reg.l + 1, 0xFF); set_inc_flags(reg.l) end
  opcode_cycles[0x34] = 12
  opcodes[0x34] = function()
    write_byte(reg.hl(), band(read_byte(reg.hl()) + 1, 0xFF))
    set_inc_flags(read_byte(reg.hl()))
  end
  opcodes[0x3C] = function() reg.a = band(reg.a + 1, 0xFF); set_inc_flags(reg.a) end

  -- dec r
  opcodes[0x05] = function() reg.b = band(reg.b - 1, 0xFF); set_dec_flags(reg.b) end
  opcodes[0x0D] = function() reg.c = band(reg.c - 1, 0xFF); set_dec_flags(reg.c) end
  opcodes[0x15] = function() reg.d = band(reg.d - 1, 0xFF); set_dec_flags(reg.d) end
  opcodes[0x1D] = function() reg.e = band(reg.e - 1, 0xFF); set_dec_flags(reg.e) end
  opcodes[0x25] = function() reg.h = band(reg.h - 1, 0xFF); set_dec_flags(reg.h) end
  opcodes[0x2D] = function() reg.l = band(reg.l - 1, 0xFF); set_dec_flags(reg.l) end
  opcode_cycles[0x35] = 12
  opcodes[0x35] = function()
    write_byte(reg.hl(), band(read_byte(reg.hl()) - 1, 0xFF))
    set_dec_flags(read_byte(reg.hl()))
  end
  opcodes[0x3D] = function() reg.a = band(reg.a - 1, 0xFF); set_dec_flags(reg.a) end
end

return apply
