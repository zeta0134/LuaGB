local bit32 = require("bit")

local lshift = bit32.lshift
local rshift = bit32.rshift
local band = bit32.band

function apply(opcodes, opcode_cycles, z80, memory)
  local read_at_hl = z80.read_at_hl
  local set_at_hl = z80.set_at_hl
  local read_nn = z80.read_nn
  local reg = z80.registers

  local read_byte = memory.read_byte
  local write_byte = memory.write_byte

  -- ld r, r
  opcodes[0x40] = function() reg.b = reg.b end
  opcodes[0x41] = function() reg.b = reg.c end
  opcodes[0x42] = function() reg.b = reg.d end
  opcodes[0x43] = function() reg.b = reg.e end
  opcodes[0x44] = function() reg.b = reg.h end
  opcodes[0x45] = function() reg.b = reg.l end
  opcode_cycles[0x46] = 8
  opcodes[0x46] = function() reg.b = read_at_hl() end
  opcodes[0x47] = function() reg.b = reg.a end

  opcodes[0x48] = function() reg.c = reg.b end
  opcodes[0x49] = function() reg.c = reg.c end
  opcodes[0x4A] = function() reg.c = reg.d end
  opcodes[0x4B] = function() reg.c = reg.e end
  opcodes[0x4C] = function() reg.c = reg.h end
  opcodes[0x4D] = function() reg.c = reg.l end
  opcode_cycles[0x4E] = 8
  opcodes[0x4E] = function() reg.c = read_at_hl() end
  opcodes[0x4F] = function() reg.c = reg.a end

  opcodes[0x50] = function() reg.d = reg.b end
  opcodes[0x51] = function() reg.d = reg.c end
  opcodes[0x52] = function() reg.d = reg.d end
  opcodes[0x53] = function() reg.d = reg.e end
  opcodes[0x54] = function() reg.d = reg.h end
  opcodes[0x55] = function() reg.d = reg.l end
  opcode_cycles[0x56] = 8
  opcodes[0x56] = function() reg.d = read_at_hl() end
  opcodes[0x57] = function() reg.d = reg.a end

  opcodes[0x58] = function() reg.e = reg.b end
  opcodes[0x59] = function() reg.e = reg.c end
  opcodes[0x5A] = function() reg.e = reg.d end
  opcodes[0x5B] = function() reg.e = reg.e end
  opcodes[0x5C] = function() reg.e = reg.h end
  opcodes[0x5D] = function() reg.e = reg.l end
  opcode_cycles[0x5E] = 8
  opcodes[0x5E] = function() reg.e = read_at_hl() end
  opcodes[0x5F] = function() reg.e = reg.a end

  opcodes[0x60] = function() reg.h = reg.b end
  opcodes[0x61] = function() reg.h = reg.c end
  opcodes[0x62] = function() reg.h = reg.d end
  opcodes[0x63] = function() reg.h = reg.e end
  opcodes[0x64] = function() reg.h = reg.h end
  opcodes[0x65] = function() reg.h = reg.l end
  opcode_cycles[0x66] = 8
  opcodes[0x66] = function() reg.h = read_at_hl() end
  opcodes[0x67] = function() reg.h = reg.a end

  opcodes[0x68] = function() reg.l = reg.b end
  opcodes[0x69] = function() reg.l = reg.c end
  opcodes[0x6A] = function() reg.l = reg.d end
  opcodes[0x6B] = function() reg.l = reg.e end
  opcodes[0x6C] = function() reg.l = reg.h end
  opcodes[0x6D] = function() reg.l = reg.l end
  opcode_cycles[0x6E] = 8
  opcodes[0x6E] = function() reg.l = read_at_hl() end
  opcodes[0x6F] = function() reg.l = reg.a end

opcode_cycles[0x70] = 8
  opcodes[0x70] = function() set_at_hl(reg.b) end

  opcode_cycles[0x71] = 8
  opcodes[0x71] = function() set_at_hl(reg.c) end

  opcode_cycles[0x72] = 8
  opcodes[0x72] = function() set_at_hl(reg.d) end

  opcode_cycles[0x73] = 8
  opcodes[0x73] = function() set_at_hl(reg.e) end

  opcode_cycles[0x74] = 8
  opcodes[0x74] = function() set_at_hl(reg.h) end

  opcode_cycles[0x75] = 8
  opcodes[0x75] = function() set_at_hl(reg.l) end

  -- 0x76 is HALT, we implement that elsewhere

  opcode_cycles[0x77] = 8
  opcodes[0x77] = function() set_at_hl(reg.a) end

  opcodes[0x78] = function() reg.a = reg.b end
  opcodes[0x79] = function() reg.a = reg.c end
  opcodes[0x7A] = function() reg.a = reg.d end
  opcodes[0x7B] = function() reg.a = reg.e end
  opcodes[0x7C] = function() reg.a = reg.h end
  opcodes[0x7D] = function() reg.a = reg.l end
  opcode_cycles[0x7E] = 8
  opcodes[0x7E] = function() reg.a = read_at_hl() end
  opcodes[0x7F] = function() reg.a = reg.a end

  -- ld r, n
  opcode_cycles[0x06] = 8
  opcodes[0x06] = function() reg.b = read_nn() end

  opcode_cycles[0x0E] = 8
  opcodes[0x0E] = function() reg.c = read_nn() end

  opcode_cycles[0x16] = 8
  opcodes[0x16] = function() reg.d = read_nn() end

  opcode_cycles[0x1E] = 8
  opcodes[0x1E] = function() reg.e = read_nn() end

  opcode_cycles[0x26] = 8
  opcodes[0x26] = function() reg.h = read_nn() end

  opcode_cycles[0x2E] = 8
  opcodes[0x2E] = function() reg.l = read_nn() end

  opcode_cycles[0x36] = 12
  opcodes[0x36] = function() set_at_hl(read_nn()) end

  opcode_cycles[0x3E] = 8
  opcodes[0x3E] = function() reg.a = read_nn() end

  -- ld A, (xx)
  opcode_cycles[0x0A] = 8
  opcodes[0x0A] = function()
    reg.a = read_byte(reg.bc())
  end

  opcode_cycles[0x1A] = 8
  opcodes[0x1A] = function()
    reg.a = read_byte(reg.de())
  end

  opcode_cycles[0xFA] = 16
  opcodes[0xFA] = function()
    local lower = read_nn()
    local upper = lshift(read_nn(), 8)
    reg.a = read_byte(upper + lower)
  end

  -- ld (xx), A
  opcode_cycles[0x02] = 8
  opcodes[0x02] = function()
    write_byte(reg.bc(), reg.a)
  end

  opcode_cycles[0x12] = 8
  opcodes[0x12] = function()
    write_byte(reg.de(), reg.a)
  end

  opcode_cycles[0xEA] = 16
  opcodes[0xEA] = function()
    local lower = read_nn()
    local upper = lshift(read_nn(), 8)
    write_byte(upper + lower, reg.a)
  end

  -- ld a, (FF00 + nn)
  opcode_cycles[0xF0] = 12
  opcodes[0xF0] = function()
    reg.a = read_byte(0xFF00 + read_nn())
  end

  -- ld (FF00 + nn), a
  opcode_cycles[0xE0] = 12
  opcodes[0xE0] = function()
    write_byte(0xFF00 + read_nn(), reg.a)
  end

  -- ld a, (FF00 + C)
  opcode_cycles[0xF2] = 8
  opcodes[0xF2] = function()
    reg.a = read_byte(0xFF00 + reg.c)
  end

  -- ld (FF00 + C), a
  opcode_cycles[0xE2] = 8
  opcodes[0xE2] = function()
    write_byte(0xFF00 + reg.c, reg.a)
  end

  -- ldi (HL), a
  opcode_cycles[0x22] = 8
  opcodes[0x22] = function()
    set_at_hl(reg.a)
    reg.set_hl(band(reg.hl() + 1, 0xFFFF))
  end

  -- ldi a, (HL)
  opcode_cycles[0x2A] = 8
  opcodes[0x2A] = function()
    reg.a = read_at_hl()
    reg.set_hl(band(reg.hl() + 1, 0xFFFF))
  end

  -- ldd (HL), a
  opcode_cycles[0x32] = 8
  opcodes[0x32] = function()
    set_at_hl(reg.a)
    reg.set_hl(band(reg.hl() - 1, 0xFFFF))
  end

  -- ldd a, (HL)
  opcode_cycles[0x3A] = 8
  opcodes[0x3A] = function()
    reg.a = read_at_hl()
    reg.set_hl(band(reg.hl() - 1, 0xFFFF))
  end

  -- ====== GMB 16-bit load commands ======
  -- ld BC, nnnn
  opcode_cycles[0x01] = 12
  opcodes[0x01] = function()
    reg.c = read_nn()
    reg.b = read_nn()
  end

  -- ld DE, nnnn
  opcode_cycles[0x11] = 12
  opcodes[0x11] = function()
    reg.e = read_nn()
    reg.d = read_nn()
  end

  -- ld HL, nnnn
  opcode_cycles[0x21] = 12
  opcodes[0x21] = function()
    reg.l = read_nn()
    reg.h = read_nn()
  end

  -- ld SP, nnnn
  opcode_cycles[0x31] = 12
  opcodes[0x31] = function()
    local lower = read_nn()
    local upper = lshift(read_nn(), 8)
    reg.sp = band(0xFFFF, upper + lower)
  end

  -- ld SP, HL
  opcode_cycles[0xF9] = 8
  opcodes[0xF9] = function()
    reg.sp = reg.hl()
  end

  -- ld HL, SP + dd
  opcode_cycles[0xF8] = 12
  opcodes[0xF8] = function()
    -- cheat
    local old_sp = reg.sp
    opcodes[0xE8]()
    reg.set_hl(reg.sp)
    reg.sp = old_sp
  end

  -- ====== GMB Special Purpose / Relocated Commands ======
  -- ld (nnnn), SP
  opcode_cycles[0x08] = 20
  opcodes[0x08] = function()
    local lower = read_nn()
    local upper = lshift(read_nn(), 8)
    local address = upper + lower
    write_byte(address, band(reg.sp, 0xFF))
    write_byte(band(address + 1, 0xFFFF), rshift(band(reg.sp, 0xFF00), 8))
  end
end

return apply
