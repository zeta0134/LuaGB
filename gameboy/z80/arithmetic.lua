local bit32 = require("bit")

local lshift = bit32.lshift
local band = bit32.band

function apply(opcodes, opcode_cycles, z80, memory)
  local read_at_hl = z80.read_at_hl
  local set_at_hl = z80.set_at_hl
  local read_nn = z80.read_nn
  local reg = z80.registers

  local read_byte = memory.read_byte
  local write_byte = memory.write_byte

  local add_to_a = function(value)
    -- half-carry
    if band(reg.a, 0xF) + band(value, 0xF) > 0xF then
      reg.flags.h = 1
    else
      reg.flags.h = 0
    end

    local sum = reg.a + value

    -- carry (and overflow correction)
    if sum > 0xFF then
      reg.flags.c = 1
    else
      reg.flags.c = 0
    end
    reg.a = band(sum, 0xFF)

    if reg.a == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end

    reg.flags.n = 0
  end

  local adc_to_a = function(value)
    -- half-carry
    if band(reg.a, 0xF) + band(value, 0xF) + reg.flags.c > 0xF then
      reg.flags.h = 1
    else
      reg.flags.h = 0
    end

    local sum = reg.a + value + reg.flags.c

    -- carry (and overflow correction)
    if sum > 0xFF then
      reg.flags.c = 1
    else
      reg.flags.c = 0
    end
    reg.a = band(sum, 0xFF)

    if reg.a == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end

    reg.flags.n = 0
  end

  -- add A, r
  opcodes[0x80] = function() add_to_a(reg.b) end
  opcodes[0x81] = function() add_to_a(reg.c) end
  opcodes[0x82] = function() add_to_a(reg.d) end
  opcodes[0x83] = function() add_to_a(reg.e) end
  opcodes[0x84] = function() add_to_a(reg.h) end
  opcodes[0x85] = function() add_to_a(reg.l) end
  opcodes[0x86] = function() add_to_a(read_at_hl()) end
  opcodes[0x87] = function() add_to_a(reg.a) end

  -- add A, nn
  opcodes[0xC6] = function() add_to_a(read_nn()) end

  -- adc A, r
  opcodes[0x88] = function() adc_to_a(reg.b) end
  opcodes[0x89] = function() adc_to_a(reg.c) end
  opcodes[0x8A] = function() adc_to_a(reg.d) end
  opcodes[0x8B] = function() adc_to_a(reg.e) end
  opcodes[0x8C] = function() adc_to_a(reg.h) end
  opcodes[0x8D] = function() adc_to_a(reg.l) end
  opcodes[0x8E] = function() adc_to_a(read_at_hl()) end
  opcodes[0x8F] = function() adc_to_a(reg.a) end

  -- adc A, nn
  opcodes[0xCE] = function() adc_to_a(read_nn()) end

  sub_from_a = function(value)
    -- half-carry
    if band(reg.a, 0xF) - band(value, 0xF) < 0 then
      reg.flags.h = 1
    else
      reg.flags.h = 0
    end

    reg.a = reg.a - value

    -- carry (and overflow correction)
    if reg.a < 0 or reg.a > 0xFF then
      reg.a = band(reg.a, 0xFF)
      reg.flags.c = 1
    else
      reg.flags.c = 0
    end

    if reg.a == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end

    reg.flags.n = 1
  end

  sbc_from_a = function(value)
    -- half-carry
    if band(reg.a, 0xF) - band(value, 0xF) - reg.flags.c < 0 then
      reg.flags.h = 1
    else
      reg.flags.h = 0
    end

    local difference = reg.a - value - reg.flags.c

    -- carry (and overflow correction)
    if difference < 0 or difference > 0xFF then
      reg.flags.c = 1
    else
      reg.flags.c = 0
    end
    reg.a = band(difference, 0xFF)

    if reg.a == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end

    reg.flags.n = 1
  end

  -- sub A, r
  opcodes[0x90] = function() sub_from_a(reg.b) end
  opcodes[0x91] = function() sub_from_a(reg.c) end
  opcodes[0x92] = function() sub_from_a(reg.d) end
  opcodes[0x93] = function() sub_from_a(reg.e) end
  opcodes[0x94] = function() sub_from_a(reg.h) end
  opcodes[0x95] = function() sub_from_a(reg.l) end
  opcodes[0x96] = function() sub_from_a(read_at_hl()) end
  opcodes[0x97] = function() sub_from_a(reg.a) end

  -- sub A, nn
  opcodes[0xD6] = function() sub_from_a(read_nn()) end

  -- sbc A, r
  opcodes[0x98] = function() sbc_from_a(reg.b) end
  opcodes[0x99] = function() sbc_from_a(reg.c) end
  opcodes[0x9A] = function() sbc_from_a(reg.d) end
  opcodes[0x9B] = function() sbc_from_a(reg.e) end
  opcodes[0x9C] = function() sbc_from_a(reg.h) end
  opcodes[0x9D] = function() sbc_from_a(reg.l) end
  opcodes[0x9E] = function() sbc_from_a(read_at_hl()) end
  opcodes[0x9F] = function() sbc_from_a(reg.a) end

  -- sbc A, nn
  opcodes[0xDE] = function() sbc_from_a(read_nn()) end
end

return apply
