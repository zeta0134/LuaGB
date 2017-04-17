local bit32 = require("bit")

local lshift = bit32.lshift
local rshift = bit32.rshift
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

  local add_to_a = function(value)
    -- half-carry
    flags.h = band(reg.a, 0xF) + band(value, 0xF) > 0xF

    local sum = reg.a + value

    -- carry (and overflow correction)
    flags.c = sum > 0xFF

    reg.a = band(sum, 0xFF)

    flags.z = reg.a == 0
    flags.n = false
  end

  local adc_to_a = function(value)
    -- half-carry
    local carry = 0
    if flags.c then
      carry = 1
    end
    flags.h = band(reg.a, 0xF) + band(value, 0xF) + carry > 0xF
    local sum = reg.a + value + carry

    -- carry (and overflow correction)
    flags.c = sum > 0xFF
    reg.a = band(sum, 0xFF)

    flags.z = reg.a == 0
    flags.n = false
  end

  -- add A, r
  opcodes[0x80] = function() add_to_a(reg.b) end
  opcodes[0x81] = function() add_to_a(reg.c) end
  opcodes[0x82] = function() add_to_a(reg.d) end
  opcodes[0x83] = function() add_to_a(reg.e) end
  opcodes[0x84] = function() add_to_a(reg.h) end
  opcodes[0x85] = function() add_to_a(reg.l) end
  opcode_cycles[0x86] = 8
  opcodes[0x86] = function() add_to_a(read_at_hl()) end
  opcodes[0x87] = function() add_to_a(reg.a) end

  -- add A, nn
  opcode_cycles[0xC6] = 8
  opcodes[0xC6] = function() add_to_a(read_nn()) end

  -- adc A, r
  opcodes[0x88] = function() adc_to_a(reg.b) end
  opcodes[0x89] = function() adc_to_a(reg.c) end
  opcodes[0x8A] = function() adc_to_a(reg.d) end
  opcodes[0x8B] = function() adc_to_a(reg.e) end
  opcodes[0x8C] = function() adc_to_a(reg.h) end
  opcodes[0x8D] = function() adc_to_a(reg.l) end
  opcode_cycles[0x8E] = 8
  opcodes[0x8E] = function() adc_to_a(read_at_hl()) end
  opcodes[0x8F] = function() adc_to_a(reg.a) end

  -- adc A, nn
  opcode_cycles[0xCE] = 8
  opcodes[0xCE] = function() adc_to_a(read_nn()) end

  sub_from_a = function(value)
    -- half-carry
    flags.h = band(reg.a, 0xF) - band(value, 0xF) < 0
    reg.a = reg.a - value

    -- carry (and overflow correction)
    flags.c = reg.a < 0 or reg.a > 0xFF
    reg.a = band(reg.a, 0xFF)

    flags.z = reg.a == 0
    flags.n = true
  end

  sbc_from_a = function(value)
    local carry = 0
    if flags.c then
      carry = 1
    end
    -- half-carry
    flags.h = band(reg.a, 0xF) - band(value, 0xF) - carry < 0

    local difference = reg.a - value - carry

    -- carry (and overflow correction)
    flags.c = difference < 0 or difference > 0xFF
    reg.a = band(difference, 0xFF)

    flags.z = reg.a == 0
    flags.n = true
  end

  -- sub A, r
  opcodes[0x90] = function() sub_from_a(reg.b) end
  opcodes[0x91] = function() sub_from_a(reg.c) end
  opcodes[0x92] = function() sub_from_a(reg.d) end
  opcodes[0x93] = function() sub_from_a(reg.e) end
  opcodes[0x94] = function() sub_from_a(reg.h) end
  opcodes[0x95] = function() sub_from_a(reg.l) end
  opcode_cycles[0x96] = 8
  opcodes[0x96] = function() sub_from_a(read_at_hl()) end
  opcodes[0x97] = function() sub_from_a(reg.a) end

  -- sub A, nn
  opcode_cycles[0xD6] = 8
  opcodes[0xD6] = function() sub_from_a(read_nn()) end

  -- sbc A, r
  opcodes[0x98] = function() sbc_from_a(reg.b) end
  opcodes[0x99] = function() sbc_from_a(reg.c) end
  opcodes[0x9A] = function() sbc_from_a(reg.d) end
  opcodes[0x9B] = function() sbc_from_a(reg.e) end
  opcodes[0x9C] = function() sbc_from_a(reg.h) end
  opcodes[0x9D] = function() sbc_from_a(reg.l) end
  opcode_cycles[0x9E] = 8
  opcodes[0x9E] = function() sbc_from_a(read_at_hl()) end
  opcodes[0x9F] = function() sbc_from_a(reg.a) end

  -- sbc A, nn
  opcode_cycles[0xDE] = 8
  opcodes[0xDE] = function() sbc_from_a(read_nn()) end

  -- daa
  -- BCD adjustment, correct implementation details located here:
  -- http://www.z80.info/z80syntx.htm#DAA
  opcodes[0x27] = function()
    local a = reg.a
    if not flags.n then
      -- Addition Mode, adjust BCD for previous addition-like instruction
      if band(0xF, a) > 0x9 or flags.h then
        a = a + 0x6
      end
      if a > 0x9F or flags.c then
        a = a + 0x60
      end
    else
      -- Subtraction mode! Adjust BCD for previous subtraction-like instruction
      if flags.h then
        a = band(a - 0x6, 0xFF)
      end
      if flags.c then
        a = a - 0x60
      end
    end
    -- Always reset H and Z
    flags.h = false
    flags.z = false

    -- If a is greater than 0xFF, set the carry flag
    if band(0x100, a) == 0x100 then
      flags.c = true
    end
    -- Note: Do NOT clear the carry flag otherwise. This is how hardware
    -- behaves, yes it's weird.

    reg.a = band(a, 0xFF)
    -- Update zero flag based on A's contents
    flags.z = reg.a == 0
  end

  add_to_hl = function(value)
    -- half carry
    flags.h = band(reg.hl(), 0xFFF) + band(value, 0xFFF) > 0xFFF
    local sum = reg.hl() + value

    -- carry
    flags.c = sum > 0xFFFF or sum < 0x0000
    reg.set_hl(band(sum, 0xFFFF))
    flags.n = false
  end

  -- add HL, rr
  opcode_cycles[0x09] = 8
  opcode_cycles[0x19] = 8
  opcode_cycles[0x29] = 8
  opcode_cycles[0x39] = 8
  opcodes[0x09] = function() add_to_hl(reg.bc()) end
  opcodes[0x19] = function() add_to_hl(reg.de()) end
  opcodes[0x29] = function() add_to_hl(reg.hl()) end
  opcodes[0x39] = function() add_to_hl(reg.sp) end

  -- inc rr
  opcode_cycles[0x03] = 8
  opcodes[0x03] = function()
    reg.set_bc(band(reg.bc() + 1, 0xFFFF))
  end

  opcode_cycles[0x13] = 8
  opcodes[0x13] = function()
    reg.set_de(band(reg.de() + 1, 0xFFFF))
  end

  opcode_cycles[0x23] = 8
  opcodes[0x23] = function()
    reg.set_hl(band(reg.hl() + 1, 0xFFFF))
  end

  opcode_cycles[0x33] = 8
  opcodes[0x33] = function()
    reg.sp = band(reg.sp + 1, 0xFFFF)
  end

  -- dec rr
  opcode_cycles[0x0B] = 8
  opcodes[0x0B] = function()
    reg.set_bc(band(reg.bc() - 1, 0xFFFF))
  end

  opcode_cycles[0x1B] = 8
  opcodes[0x1B] = function()
    reg.set_de(band(reg.de() - 1, 0xFFFF))
  end

  opcode_cycles[0x2B] = 8
  opcodes[0x2B] = function()
    reg.set_hl(band(reg.hl() - 1, 0xFFFF))
  end

  opcode_cycles[0x3B] = 8
  opcodes[0x3B] = function()
    reg.sp = band(reg.sp - 1, 0xFFFF)
  end

  -- add SP, dd
  opcode_cycles[0xE8] = 16
  opcodes[0xE8] = function()
    local offset = read_nn()
    -- offset comes in as unsigned 0-255, so convert it to signed -128 - 127
    if band(offset, 0x80) ~= 0 then
      offset = offset + 0xFF00
    end

    -- half carry
    --if band(reg.sp, 0xFFF) + offset > 0xFFF or band(reg.sp, 0xFFF) + offset < 0 then
    flags.h = band(reg.sp, 0xF) + band(offset, 0xF) > 0xF
    -- carry
    flags.c = band(reg.sp, 0xFF) + band(offset, 0xFF) > 0xFF

    reg.sp = reg.sp + offset
    reg.sp = band(reg.sp, 0xFFFF)

    flags.z = false
    flags.n = false
  end
end

return apply
