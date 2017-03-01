local bit32 = require("bit")

local Z80 = {}

function Z80.new(modules)
  local z80 = {}

  local interrupts = modules.interrupts
  local io = modules.io
  local memory = modules.memory
  local timers = modules.timers

  -- local references, for shorter code
  local read_byte = memory.read_byte
  local write_byte = memory.write_byte

  local lshift = bit32.lshift
  local rshift = bit32.rshift
  local band = bit32.band
  local bxor = bit32.bxor
  local bor = bit32.bor
  local bnot = bit32.bnot

  -- Initialize registers to what the GB's
  -- iternal state would be after executing
  -- BIOS code

  -- Intentionally bad naming convention: I am NOT typing "registers"
  -- a bazillion times. The exported symbol uses the full name as a
  -- reasonable compromise.
  z80.registers = {}
  local reg = z80.registers
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

  z80.halted = 0

  local add_cycles_normal = function(cycles)
    timers.system_clock = timers.system_clock + cycles
  end

  local add_cycles_double = function(cycles)
    timers.system_clock = timers.system_clock + cycles / 2
  end

  local add_cycles = add_cycles_normal
  local double_speed = false

  z80.reset = function(gameboy)
    reg.flags.z = 1
    reg.flags.n = 0
    reg.flags.h = 1
    reg.flags.c = 1

    if gameboy.type == gameboy.types.color then
      reg.a = 0x11
    else
      reg.a = 0x01
    end
    reg.b = 0x00
    reg.c = 0x13
    reg.d = 0x00
    reg.e = 0xD8
    reg.h = 0x01
    reg.l = 0x4D
    reg.pc = 0x100 --entrypoint for GB games
    reg.sp = 0xFFFE

    z80.halted = 0

    double_speed = false
    add_cycles = add_cycles_normal
    timers.set_normal_speed()
  end

  z80.save_state = function()
    local state = {}
    state.registers = z80.registers
    state.halted = z80.halted
    return state
  end

  z80.load_state = function(state)
    -- Note: doing this explicitly for safety, so as
    -- not to replace the table with external, possibly old / wrong structure
    reg.flags.z = state.registers.flags.z
    reg.flags.n = state.registers.flags.n
    reg.flags.h = state.registers.flags.h
    reg.flags.c = state.registers.flags.c

    z80.registers.a = state.registers.a
    z80.registers.b = state.registers.b
    z80.registers.c = state.registers.c
    z80.registers.d = state.registers.d
    z80.registers.e = state.registers.e
    z80.registers.h = state.registers.h
    z80.registers.l = state.registers.l
    z80.registers.pc = state.registers.pc
    z80.registers.sp = state.registers.sp

    z80.halted = state.halted
  end

  io.write_mask[0x4D] = 0x01

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

  local opcodes = {}
  local opcode_names = {}

  function read_at_hl()
    add_cycles(4)
    return read_byte(reg.hl())
  end

  function set_at_hl(value)
    add_cycles(4)
    write_byte(reg.hl(), value)
  end

  -- ====== GMB 8-bit load commands ======

  -- ld r, r
  opcodes[0x40] = function() reg.b = reg.b end
  opcodes[0x41] = function() reg.b = reg.c end
  opcodes[0x42] = function() reg.b = reg.d end
  opcodes[0x43] = function() reg.b = reg.e end
  opcodes[0x44] = function() reg.b = reg.h end
  opcodes[0x45] = function() reg.b = reg.l end
  opcodes[0x46] = function() reg.b = read_at_hl() end
  opcodes[0x47] = function() reg.b = reg.a end

  opcodes[0x48] = function() reg.c = reg.b end
  opcodes[0x49] = function() reg.c = reg.c end
  opcodes[0x4A] = function() reg.c = reg.d end
  opcodes[0x4B] = function() reg.c = reg.e end
  opcodes[0x4C] = function() reg.c = reg.h end
  opcodes[0x4D] = function() reg.c = reg.l end
  opcodes[0x4E] = function() reg.c = read_at_hl() end
  opcodes[0x4F] = function() reg.c = reg.a end

  opcodes[0x50] = function() reg.d = reg.b end
  opcodes[0x51] = function() reg.d = reg.c end
  opcodes[0x52] = function() reg.d = reg.d end
  opcodes[0x53] = function() reg.d = reg.e end
  opcodes[0x54] = function() reg.d = reg.h end
  opcodes[0x55] = function() reg.d = reg.l end
  opcodes[0x56] = function() reg.d = read_at_hl() end
  opcodes[0x57] = function() reg.d = reg.a end

  opcodes[0x58] = function() reg.e = reg.b end
  opcodes[0x59] = function() reg.e = reg.c end
  opcodes[0x5A] = function() reg.e = reg.d end
  opcodes[0x5B] = function() reg.e = reg.e end
  opcodes[0x5C] = function() reg.e = reg.h end
  opcodes[0x5D] = function() reg.e = reg.l end
  opcodes[0x5E] = function() reg.e = read_at_hl() end
  opcodes[0x5F] = function() reg.e = reg.a end

  opcodes[0x60] = function() reg.h = reg.b end
  opcodes[0x61] = function() reg.h = reg.c end
  opcodes[0x62] = function() reg.h = reg.d end
  opcodes[0x63] = function() reg.h = reg.e end
  opcodes[0x64] = function() reg.h = reg.h end
  opcodes[0x65] = function() reg.h = reg.l end
  opcodes[0x66] = function() reg.h = read_at_hl() end
  opcodes[0x67] = function() reg.h = reg.a end

  opcodes[0x68] = function() reg.l = reg.b end
  opcodes[0x69] = function() reg.l = reg.c end
  opcodes[0x6A] = function() reg.l = reg.d end
  opcodes[0x6B] = function() reg.l = reg.e end
  opcodes[0x6C] = function() reg.l = reg.h end
  opcodes[0x6D] = function() reg.l = reg.l end
  opcodes[0x6E] = function() reg.l = read_at_hl() end
  opcodes[0x6F] = function() reg.l = reg.a end

  opcodes[0x70] = function() set_at_hl(reg.b) end
  opcodes[0x71] = function() set_at_hl(reg.c) end
  opcodes[0x72] = function() set_at_hl(reg.d) end
  opcodes[0x73] = function() set_at_hl(reg.e) end
  opcodes[0x74] = function() set_at_hl(reg.h) end
  opcodes[0x75] = function() set_at_hl(reg.l) end
  -- 0x76 is HALT, we implement that later
  opcodes[0x77] = function() set_at_hl(reg.a) end

  opcodes[0x78] = function() reg.a = reg.b end
  opcodes[0x79] = function() reg.a = reg.c end
  opcodes[0x7A] = function() reg.a = reg.d end
  opcodes[0x7B] = function() reg.a = reg.e end
  opcodes[0x7C] = function() reg.a = reg.h end
  opcodes[0x7D] = function() reg.a = reg.l end
  opcodes[0x7E] = function() reg.a = read_at_hl() end
  opcodes[0x7F] = function() reg.a = reg.a end

  function read_nn()
    local nn = read_byte(reg.pc)
    reg.pc = reg.pc + 1
    add_cycles(4)
    return nn
  end

  -- ld r, n
  opcodes[0x06] = function() reg.b = read_nn() end
  opcodes[0x0E] = function() reg.c = read_nn() end
  opcodes[0x16] = function() reg.d = read_nn() end
  opcodes[0x1E] = function() reg.e = read_nn() end
  opcodes[0x26] = function() reg.h = read_nn() end
  opcodes[0x2E] = function() reg.l = read_nn() end
  opcodes[0x36] = function() set_at_hl(read_nn()) end
  opcodes[0x3E] = function() reg.a = read_nn() end

  -- ld A, (xx)
  opcodes[0x0A] = function()
    reg.a = read_byte(reg.bc())
    add_cycles(4)
  end

  opcodes[0x1A] = function()
    reg.a = read_byte(reg.de())
    add_cycles(4)
  end

  opcodes[0xFA] = function()
    local lower = read_nn()
    local upper = lshift(read_nn(), 8)
    reg.a = read_byte(upper + lower)
    add_cycles(4)
  end

  -- ld (xx), A
  opcodes[0x02] = function()
    write_byte(reg.bc(), reg.a)
    add_cycles(4)
  end

  opcodes[0x12] = function()
    write_byte(reg.de(), reg.a)
    add_cycles(4)
  end

  opcodes[0xEA] = function()
    local lower = read_nn()
    local upper = lshift(read_nn(), 8)
    write_byte(upper + lower, reg.a)
    add_cycles(4)
  end

  -- ld a, (FF00 + nn)
  opcodes[0xF0] = function()
    reg.a = read_byte(0xFF00 + read_nn())
    add_cycles(4)
  end

  -- ld (FF00 + nn), a
  opcodes[0xE0] = function()
    write_byte(0xFF00 + read_nn(), reg.a)
    add_cycles(4)
  end

  -- ld a, (FF00 + C)
  opcodes[0xF2] = function()
    reg.a = read_byte(0xFF00 + reg.c)
    add_cycles(4)
  end

  -- ld (FF00 + C), a
  opcodes[0xE2] = function()
    write_byte(0xFF00 + reg.c, reg.a)
    add_cycles(4)
  end

  -- ldi (HL), a
  opcodes[0x22] = function()
    set_at_hl(reg.a)
    reg.set_hl(band(reg.hl() + 1, 0xFFFF))
  end

  -- ldi a, (HL)
  opcodes[0x2A] = function()
    reg.a = read_at_hl()
    reg.set_hl(band(reg.hl() + 1, 0xFFFF))
  end

  -- ldd (HL), a
  opcodes[0x32] = function()
    set_at_hl(reg.a)
    reg.set_hl(band(reg.hl() - 1, 0xFFFF))
  end

  -- ldd a, (HL)
  opcodes[0x3A] = function()
    reg.a = read_at_hl()
    reg.set_hl(band(reg.hl() - 1, 0xFFFF))
  end

  -- ====== GMB 16-bit load commands ======
  -- ld BC, nnnn
  opcodes[0x01] = function()
    reg.c = read_nn()
    reg.b = read_nn()
  end

  -- ld DE, nnnn
  opcodes[0x11] = function()
    reg.e = read_nn()
    reg.d = read_nn()
  end

  -- ld HL, nnnn
  opcodes[0x21] = function()
    reg.l = read_nn()
    reg.h = read_nn()
  end

  -- ld SP, nnnn
  opcodes[0x31] = function()
    local lower = read_nn()
    local upper = lshift(read_nn(), 8)
    reg.sp = band(0xFFFF, upper + lower)
  end

  -- ld SP, HL
  opcodes[0xF9] = function()
    reg.sp = reg.hl()
    add_cycles(4)
  end

  -- push BC
  opcodes[0xC5] = function()
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.b)
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.c)
    add_cycles(12)
  end

  -- push DE
  opcodes[0xD5] = function()
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.d)
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.e)
    add_cycles(12)
  end

  -- push HL
  opcodes[0xE5] = function()
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.h)
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.l)
    add_cycles(12)
  end

  -- push AF
  opcodes[0xF5] = function()
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.a)
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, reg.f())
    add_cycles(12)
  end

  -- pop BC
  opcodes[0xC1] = function()
    reg.c = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
    reg.b = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
    add_cycles(8)
  end

  -- pop DE
  opcodes[0xD1] = function()
    reg.e = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
    reg.d = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
    add_cycles(8)
  end

  -- pop HL
  opcodes[0xE1] = function()
    reg.l = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
    reg.h = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
    add_cycles(8)
  end

  -- pop AF
  opcodes[0xF1] = function()
    reg.set_f(read_byte(reg.sp))
    reg.sp = band(0xFFFF, reg.sp + 1)
    reg.a = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
    add_cycles(8)
  end

  -- ====== GMB 8bit-Arithmetic/logical Commands ======
  add_to_a = function(value)
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

  adc_to_a = function(value)
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

  and_a_with = function(value)
    reg.a = band(reg.a, value)
    if reg.a == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end
    reg.flags.n = 0
    reg.flags.h = 1
    reg.flags.c = 0
  end

  -- and A, r
  opcodes[0xA0] = function() and_a_with(reg.b) end
  opcodes[0xA1] = function() and_a_with(reg.c) end
  opcodes[0xA2] = function() and_a_with(reg.d) end
  opcodes[0xA3] = function() and_a_with(reg.e) end
  opcodes[0xA4] = function() and_a_with(reg.h) end
  opcodes[0xA5] = function() and_a_with(reg.l) end
  opcodes[0xA6] = function() and_a_with(read_at_hl()) end
  opcodes[0xA7] = function() and_a_with(reg.a) end

  -- and A, nn
  opcodes[0xE6] = function() and_a_with(read_nn()) end

  xor_a_with = function(value)
    reg.a = bxor(reg.a, value)
    if reg.a == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end
    reg.flags.n = 0
    reg.flags.h = 0
    reg.flags.c = 0
  end

  -- xor A, r
  opcodes[0xA8] = function() xor_a_with(reg.b) end
  opcodes[0xA9] = function() xor_a_with(reg.c) end
  opcodes[0xAA] = function() xor_a_with(reg.d) end
  opcodes[0xAB] = function() xor_a_with(reg.e) end
  opcodes[0xAC] = function() xor_a_with(reg.h) end
  opcodes[0xAD] = function() xor_a_with(reg.l) end
  opcodes[0xAE] = function() xor_a_with(read_at_hl()) end
  opcodes[0xAF] = function() xor_a_with(reg.a) end

  -- xor A, nn
  opcodes[0xEE] = function() xor_a_with(read_nn()) end

  or_a_with = function(value)
    reg.a = bor(reg.a, value)
    if reg.a == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end
    reg.flags.n = 0
    reg.flags.h = 0
    reg.flags.c = 0
  end

  -- or A, r
  opcodes[0xB0] = function() or_a_with(reg.b) end
  opcodes[0xB1] = function() or_a_with(reg.c) end
  opcodes[0xB2] = function() or_a_with(reg.d) end
  opcodes[0xB3] = function() or_a_with(reg.e) end
  opcodes[0xB4] = function() or_a_with(reg.h) end
  opcodes[0xB5] = function() or_a_with(reg.l) end
  opcodes[0xB6] = function() or_a_with(read_at_hl()) end
  opcodes[0xB7] = function() or_a_with(reg.a) end

  -- or A, nn
  opcodes[0xF6] = function() or_a_with(read_nn()) end

  cp_with_a = function(value)
    -- half-carry
    --if band(reg.a, 0xF) - band(value, 0xF) < 0 then
    if (reg.a % 0x10) - (value % 0x10) < 0 then
      reg.flags.h = 1
    else
      reg.flags.h = 0
    end

    local temp = reg.a - value

    -- carry (and overflow correction)
    if temp < 0 or temp > 0xFF then
      --temp  = band(temp, 0xFF)
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
  opcodes[0xBE] = function() cp_with_a(read_at_hl()) end
  opcodes[0xBF] = function() cp_with_a(reg.a) end

  -- cp A, nn
  opcodes[0xFE] = function() cp_with_a(read_nn()) end

  set_inc_flags = function(value)
    -- zero flag
    if value == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end

    -- half-carry
    if value % 0x10 == 0x0 then
      reg.flags.h = 1
    else
      reg.flags.h = 0
    end

    reg.flags.n = 0
  end

  set_dec_flags = function(value)
    -- zero flag
    if value == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end

    -- half-carry
    if value % 0x10 == 0xF then
      reg.flags.h = 1
    else
      reg.flags.h = 0
    end

    reg.flags.n = 1
  end

  -- inc r
  opcodes[0x04] = function() reg.b = band(reg.b + 1, 0xFF); set_inc_flags(reg.b) end
  opcodes[0x0C] = function() reg.c = band(reg.c + 1, 0xFF); set_inc_flags(reg.c) end
  opcodes[0x14] = function() reg.d = band(reg.d + 1, 0xFF); set_inc_flags(reg.d) end
  opcodes[0x1C] = function() reg.e = band(reg.e + 1, 0xFF); set_inc_flags(reg.e) end
  opcodes[0x24] = function() reg.h = band(reg.h + 1, 0xFF); set_inc_flags(reg.h) end
  opcodes[0x2C] = function() reg.l = band(reg.l + 1, 0xFF); set_inc_flags(reg.l) end
  opcodes[0x34] = function()
    write_byte(reg.hl(), band(read_byte(reg.hl()) + 1, 0xFF))
    set_inc_flags(read_byte(reg.hl()))
    add_cycles(8)
  end
  opcodes[0x3C] = function() reg.a = band(reg.a + 1, 0xFF); set_inc_flags(reg.a) end

  -- dec r
  opcodes[0x05] = function() reg.b = band(reg.b - 1, 0xFF); set_dec_flags(reg.b) end
  opcodes[0x0D] = function() reg.c = band(reg.c - 1, 0xFF); set_dec_flags(reg.c) end
  opcodes[0x15] = function() reg.d = band(reg.d - 1, 0xFF); set_dec_flags(reg.d) end
  opcodes[0x1D] = function() reg.e = band(reg.e - 1, 0xFF); set_dec_flags(reg.e) end
  opcodes[0x25] = function() reg.h = band(reg.h - 1, 0xFF); set_dec_flags(reg.h) end
  opcodes[0x2D] = function() reg.l = band(reg.l - 1, 0xFF); set_dec_flags(reg.l) end
  opcodes[0x35] = function()
    write_byte(reg.hl(), band(read_byte(reg.hl()) - 1, 0xFF))
    set_dec_flags(read_byte(reg.hl()))
    add_cycles(8)
  end
  opcodes[0x3D] = function() reg.a = band(reg.a - 1, 0xFF); set_dec_flags(reg.a) end

  -- daa
  -- BCD adjustment, correct implementation details located here:
  -- http://www.z80.info/z80syntx.htm#DAA
  opcodes[0x27] = function()
    local a = reg.a
    if reg.flags.n == 0 then
      -- Addition Mode, adjust BCD for previous addition-like instruction
      if band(0xF, a) > 0x9 or reg.flags.h == 1 then
        a = a + 0x6
      end
      if a > 0x9F or reg.flags.c == 1 then
        a = a + 0x60
      end
    else
      -- Subtraction mode! Adjust BCD for previous subtraction-like instruction
      if reg.flags.h == 1 then
        a = band(a - 0x6, 0xFF)
      end
      if reg.flags.c == 1 then
        a = a - 0x60
      end
    end
    -- Always reset H and Z
    reg.flags.h = 0
    reg.flags.z = 0

    -- If a is greater than 0xFF, set the carry flag
    if band(0x100, a) == 0x100 then
      reg.flags.c = 1
    end
    reg.a = band(a, 0xFF)
    -- Update zero flag based on A's contents
    if reg.a == 0 then
      reg.flags.z = 1
    end
  end

  -- cpl
  opcodes[0x2F] = function()
    reg.a = bxor(reg.a, 0xFF)
    reg.flags.n = 1
    reg.flags.h = 1
  end

  add_to_hl = function(value)
    -- half carry
    if band(reg.hl(), 0xFFF) + band(value, 0xFFF) > 0xFFF then
      reg.flags.h = 1
    else
      reg.flags.h = 0
    end

    local sum = reg.hl() + value

    -- carry
    if sum > 0xFFFF or sum < 0x0000 then
      reg.flags.c = 1
    else
      reg.flags.c = 0
    end
    reg.set_hl(band(sum, 0xFFFF))
    reg.flags.n = 0
    add_cycles(4)
  end

  -- add HL, rr
  opcodes[0x09] = function() add_to_hl(reg.bc()) end
  opcodes[0x19] = function() add_to_hl(reg.de()) end
  opcodes[0x29] = function() add_to_hl(reg.hl()) end
  opcodes[0x39] = function() add_to_hl(reg.sp) end

  -- inc rr
  opcodes[0x03] = function()
    reg.set_bc(band(reg.bc() + 1, 0xFFFF))
    add_cycles(4)
  end
  opcodes[0x13] = function()
    reg.set_de(band(reg.de() + 1, 0xFFFF))
    add_cycles(4)
  end
  opcodes[0x23] = function()
    reg.set_hl(band(reg.hl() + 1, 0xFFFF))
    add_cycles(4)
  end
  opcodes[0x33] = function()
    reg.sp = band(reg.sp + 1, 0xFFFF)
    add_cycles(4)
  end

  -- dec rr
  opcodes[0x0B] = function()
    reg.set_bc(band(reg.bc() - 1, 0xFFFF))
    add_cycles(4)
  end
  opcodes[0x1B] = function()
    reg.set_de(band(reg.de() - 1, 0xFFFF))
    add_cycles(4)
  end
  opcodes[0x2B] = function()
    reg.set_hl(band(reg.hl() - 1, 0xFFFF))
    add_cycles(4)
  end
  opcodes[0x3B] = function()
    reg.sp = band(reg.sp - 1, 0xFFFF)
    add_cycles(4)
  end

  -- add SP, dd
  opcodes[0xE8] = function()
    local offset = read_nn()
    -- offset comes in as unsigned 0-255, so convert it to signed -128 - 127
    if band(offset, 0x80) ~= 0 then
      offset = offset + 0xFF00
    end

    -- half carry
    --if band(reg.sp, 0xFFF) + offset > 0xFFF or band(reg.sp, 0xFFF) + offset < 0 then
    if band(reg.sp, 0xF) + band(offset, 0xF) > 0xF then
      reg.flags.h = 1
    else
      reg.flags.h = 0
    end
    -- carry
    if band(reg.sp, 0xFF) + band(offset, 0xFF) > 0xFF then
      reg.flags.c = 1
    else
      reg.flags.c = 0
    end

    reg.sp = reg.sp + offset
    reg.sp = band(reg.sp, 0xFFFF)

    reg.flags.z = 0
    reg.flags.n = 0

    add_cycles(8)
  end

  -- ld HL, SP + dd
  opcodes[0xF8] = function()
    -- cheat
    local old_sp = reg.sp
    opcodes[0xE8]()
    reg.set_hl(reg.sp)
    reg.sp = old_sp
    --op E8 is 12 clocks, this is 8 clocks less
    add_cycles(-4)
  end

  -- ====== GMB Rotate and Shift Commands ======
  local reg_rlc = function(value)
    value = lshift(value, 1)
    -- move what would be bit 8 into the carry
    if band(value, 0x100) ~= 0 then
      value = band(value, 0xFF)
      reg.flags.c = 1
    else
      reg.flags.c = 0
    end
    -- also copy the carry into bit 0
    value = value + reg.flags.c
    if value == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end
    reg.flags.h = 0
    reg.flags.n = 0
    return value
  end

  local reg_rl = function(value)
    value = lshift(value, 1)
    -- move the carry into bit 0
    value = value + reg.flags.c
    -- now move what would be bit 8 into the carry
    if band(value, 0x100) ~= 0 then
      value = band(value, 0xFF)
      reg.flags.c = 1
    else
      reg.flags.c = 0
    end
    if value == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end
    reg.flags.h = 0
    reg.flags.n = 0
    return value
  end

  local reg_rrc = function(value)
    -- move bit 0 into the carry
    if band(value, 0x1) ~= 0 then
      reg.flags.c = 1
    else
      reg.flags.c = 0
    end
    value = rshift(value, 1)
    -- also copy the carry into bit 7
    value = value + lshift(reg.flags.c, 7)
    if value == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end
    reg.flags.h = 0
    reg.flags.n = 0
    return value
  end

  local reg_rr = function(value)
    -- first, copy the carry into bit 8 (!!)
    value = value + lshift(reg.flags.c, 8)
    -- move bit 0 into the carry
    if band(value, 0x1) ~= 0 then
      reg.flags.c = 1
    else
      reg.flags.c = 0
    end
    value = rshift(value, 1)
    -- for safety, this should be a nop?
    value = band(value, 0xFF)
    if value == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end
    reg.flags.h = 0
    reg.flags.n = 0
    return value
  end

  -- rlc a
  opcodes[0x07] = function() reg.a = reg_rlc(reg.a); reg.flags.z = 0 end

  -- rl a
  opcodes[0x17] = function() reg.a = reg_rl(reg.a); reg.flags.z = 0 end

  -- rrc a
  opcodes[0x0F] = function() reg.a = reg_rrc(reg.a); reg.flags.z = 0 end

  -- rr a
  opcodes[0x1F] = function() reg.a = reg_rr(reg.a); reg.flags.z = 0 end

  -- ====== CB: Extended Rotate and Shift ======

  cb = {}

  -- rlc r
  cb[0x00] = function() reg.b = reg_rlc(reg.b); add_cycles(4) end
  cb[0x01] = function() reg.c = reg_rlc(reg.c); add_cycles(4) end
  cb[0x02] = function() reg.d = reg_rlc(reg.d); add_cycles(4) end
  cb[0x03] = function() reg.e = reg_rlc(reg.e); add_cycles(4) end
  cb[0x04] = function() reg.h = reg_rlc(reg.h); add_cycles(4) end
  cb[0x05] = function() reg.l = reg_rlc(reg.l); add_cycles(4) end
  cb[0x06] = function() write_byte(reg.hl(), reg_rlc(read_byte(reg.hl()))); add_cycles(12) end
  cb[0x07] = function() reg.a = reg_rlc(reg.a); add_cycles(4) end

  -- rl r
  cb[0x10] = function() reg.b = reg_rl(reg.b); add_cycles(4) end
  cb[0x11] = function() reg.c = reg_rl(reg.c); add_cycles(4) end
  cb[0x12] = function() reg.d = reg_rl(reg.d); add_cycles(4) end
  cb[0x13] = function() reg.e = reg_rl(reg.e); add_cycles(4) end
  cb[0x14] = function() reg.h = reg_rl(reg.h); add_cycles(4) end
  cb[0x15] = function() reg.l = reg_rl(reg.l); add_cycles(4) end
  cb[0x16] = function() write_byte(reg.hl(), reg_rl(read_byte(reg.hl()))); add_cycles(12) end
  cb[0x17] = function() reg.a = reg_rl(reg.a); add_cycles(4) end

  -- rrc r
  cb[0x08] = function() reg.b = reg_rrc(reg.b); add_cycles(4) end
  cb[0x09] = function() reg.c = reg_rrc(reg.c); add_cycles(4) end
  cb[0x0A] = function() reg.d = reg_rrc(reg.d); add_cycles(4) end
  cb[0x0B] = function() reg.e = reg_rrc(reg.e); add_cycles(4) end
  cb[0x0C] = function() reg.h = reg_rrc(reg.h); add_cycles(4) end
  cb[0x0D] = function() reg.l = reg_rrc(reg.l); add_cycles(4) end
  cb[0x0E] = function() write_byte(reg.hl(), reg_rrc(read_byte(reg.hl()))); add_cycles(12) end
  cb[0x0F] = function() reg.a = reg_rrc(reg.a); add_cycles(4) end

  -- rl r
  cb[0x18] = function() reg.b = reg_rr(reg.b); add_cycles(4) end
  cb[0x19] = function() reg.c = reg_rr(reg.c); add_cycles(4) end
  cb[0x1A] = function() reg.d = reg_rr(reg.d); add_cycles(4) end
  cb[0x1B] = function() reg.e = reg_rr(reg.e); add_cycles(4) end
  cb[0x1C] = function() reg.h = reg_rr(reg.h); add_cycles(4) end
  cb[0x1D] = function() reg.l = reg_rr(reg.l); add_cycles(4) end
  cb[0x1E] = function() write_byte(reg.hl(), reg_rr(read_byte(reg.hl()))); add_cycles(12) end
  cb[0x1F] = function() reg.a = reg_rr(reg.a); add_cycles(4) end

  reg_sla = function(value)
    -- copy bit 7 into carry
    if band(value, 0x80) == 0x80 then
      reg.flags.c = 1
    else
      reg.flags.c = 0
    end
    value = band(lshift(value, 1), 0xFF)
    if value == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end
    reg.flags.h = 0
    reg.flags.n = 0
    add_cycles(4)
    return value
  end

  reg_srl = function(value)
    -- copy bit 0 into carry
    if band(value, 0x1) == 1 then
      reg.flags.c = 1
    else
      reg.flags.c = 0
    end
    value = rshift(value, 1)
    if value == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end
    reg.flags.h = 0
    reg.flags.n = 0
    add_cycles(4)
    return value
  end

  reg_sra = function(value)
    local arith_value = reg_srl(value)
    -- if bit 6 is set, copy it to bit 7
    if band(arith_value, 0x40) ~= 0 then
      arith_value = arith_value + 0x80
    end
    add_cycles(4)
    return arith_value
  end

  reg_swap = function(value)
    value = rshift(band(value, 0xF0), 4) + lshift(band(value, 0xF), 4)
    if value == 0 then
      reg.flags.z = 1
    else
      reg.flags.z = 0
    end
    reg.flags.n = 0
    reg.flags.h = 0
    reg.flags.c = 0
    add_cycles(4)
    return value
  end

  -- sla r
  cb[0x20] = function() reg.b = reg_sla(reg.b) end
  cb[0x21] = function() reg.c = reg_sla(reg.c) end
  cb[0x22] = function() reg.d = reg_sla(reg.d) end
  cb[0x23] = function() reg.e = reg_sla(reg.e) end
  cb[0x24] = function() reg.h = reg_sla(reg.h) end
  cb[0x25] = function() reg.l = reg_sla(reg.l) end
  cb[0x26] = function() write_byte(reg.hl(), reg_sla(read_byte(reg.hl()))); add_cycles(8) end
  cb[0x27] = function() reg.a = reg_sla(reg.a) end

  -- swap r (high and low nybbles)
  cb[0x30] = function() reg.b = reg_swap(reg.b) end
  cb[0x31] = function() reg.c = reg_swap(reg.c) end
  cb[0x32] = function() reg.d = reg_swap(reg.d) end
  cb[0x33] = function() reg.e = reg_swap(reg.e) end
  cb[0x34] = function() reg.h = reg_swap(reg.h) end
  cb[0x35] = function() reg.l = reg_swap(reg.l) end
  cb[0x36] = function() write_byte(reg.hl(), reg_swap(read_byte(reg.hl()))); add_cycles(8) end
  cb[0x37] = function() reg.a = reg_swap(reg.a) end

  -- sra r
  cb[0x28] = function() reg.b = reg_sra(reg.b); add_cycles(-4) end
  cb[0x29] = function() reg.c = reg_sra(reg.c); add_cycles(-4) end
  cb[0x2A] = function() reg.d = reg_sra(reg.d); add_cycles(-4) end
  cb[0x2B] = function() reg.e = reg_sra(reg.e); add_cycles(-4) end
  cb[0x2C] = function() reg.h = reg_sra(reg.h); add_cycles(-4) end
  cb[0x2D] = function() reg.l = reg_sra(reg.l); add_cycles(-4) end
  cb[0x2E] = function() write_byte(reg.hl(), reg_sra(read_byte(reg.hl()))); add_cycles(4) end
  cb[0x2F] = function() reg.a = reg_sra(reg.a); add_cycles(-4) end

  -- srl r
  cb[0x38] = function() reg.b = reg_srl(reg.b) end
  cb[0x39] = function() reg.c = reg_srl(reg.c) end
  cb[0x3A] = function() reg.d = reg_srl(reg.d) end
  cb[0x3B] = function() reg.e = reg_srl(reg.e) end
  cb[0x3C] = function() reg.h = reg_srl(reg.h) end
  cb[0x3D] = function() reg.l = reg_srl(reg.l) end
  cb[0x3E] = function() write_byte(reg.hl(), reg_srl(read_byte(reg.hl()))); add_cycles(8) end
  cb[0x3F] = function() reg.a = reg_srl(reg.a) end

  -- ====== GMB Special Purpose / Relocated Commands ======
  -- ld (nnnn), SP
  opcodes[0x08] = function()
    local lower = read_nn()
    local upper = lshift(read_nn(), 8)
    local address = upper + lower
    write_byte(address, band(reg.sp, 0xFF))
    write_byte(band(address + 1, 0xFFFF), rshift(band(reg.sp, 0xFF00), 8))
    add_cycles(8)
  end

  -- ====== GMB Singlebit Operation Commands ======
  reg_bit = function(value, bit)
    if band(value, lshift(0x1, bit)) ~= 0 then
      reg.flags.z = 0
    else
      reg.flags.z = 1
    end
    reg.flags.n = 0
    reg.flags.h = 1
    return
  end

  opcodes[0xCB] = function()
    local cb_op = read_nn()
    if cb[cb_op] ~= nil then
      --revert the timing; this is handled automatically by the various functions
      add_cycles(-4)
      cb[cb_op]()
      return
    end
    local high_half_nybble = rshift(band(cb_op, 0xC0), 6)
    local reg_index = band(cb_op, 0x7)
    local bit = rshift(band(cb_op, 0x38), 3)
    if high_half_nybble == 0x1 then
      -- bit n,r
      if reg_index == 0 then reg_bit(reg.b, bit) end
      if reg_index == 1 then reg_bit(reg.c, bit) end
      if reg_index == 2 then reg_bit(reg.d, bit) end
      if reg_index == 3 then reg_bit(reg.e, bit) end
      if reg_index == 4 then reg_bit(reg.h, bit) end
      if reg_index == 5 then reg_bit(reg.l, bit) end
      if reg_index == 6 then reg_bit(read_byte(reg.hl()), bit); add_cycles(4) end
      if reg_index == 7 then reg_bit(reg.a, bit) end
    end
    if high_half_nybble == 0x2 then
      -- res n, r
      -- note: this is REALLY stupid, but it works around some floating point
      -- limitations in Lua.
      if reg_index == 0 then reg.b = band(reg.b, bxor(reg.b, lshift(0x1, bit))) end
      if reg_index == 1 then reg.c = band(reg.c, bxor(reg.c, lshift(0x1, bit))) end
      if reg_index == 2 then reg.d = band(reg.d, bxor(reg.d, lshift(0x1, bit))) end
      if reg_index == 3 then reg.e = band(reg.e, bxor(reg.e, lshift(0x1, bit))) end
      if reg_index == 4 then reg.h = band(reg.h, bxor(reg.h, lshift(0x1, bit))) end
      if reg_index == 5 then reg.l = band(reg.l, bxor(reg.l, lshift(0x1, bit))) end
      if reg_index == 6 then write_byte(reg.hl(), band(read_byte(reg.hl()), bxor(read_byte(reg.hl()), lshift(0x1, bit)))); add_cycles(8) end
      if reg_index == 7 then reg.a = band(reg.a, bxor(reg.a, lshift(0x1, bit))) end
    end

    if high_half_nybble == 0x3 then
      -- set n, r
      if reg_index == 0 then reg.b = bor(lshift(0x1, bit), reg.b) end
      if reg_index == 1 then reg.c = bor(lshift(0x1, bit), reg.c) end
      if reg_index == 2 then reg.d = bor(lshift(0x1, bit), reg.d) end
      if reg_index == 3 then reg.e = bor(lshift(0x1, bit), reg.e) end
      if reg_index == 4 then reg.h = bor(lshift(0x1, bit), reg.h) end
      if reg_index == 5 then reg.l = bor(lshift(0x1, bit), reg.l) end
      if reg_index == 6 then write_byte(reg.hl(), bor(lshift(0x1, bit), read_byte(reg.hl()))); add_cycles(8) end
      if reg_index == 7 then reg.a = bor(lshift(0x1, bit), reg.a) end
    end
  end

  -- ====== GMB CPU-Controlcommands ======
  -- ccf
  opcodes[0x3F] = function()
    --reg.flags.c = bnot(reg.flags.c)
    reg.flags.c = band(0x1, bnot(reg.flags.c))
    reg.flags.n = 0
    reg.flags.h = 0
  end

  -- scf
  opcodes[0x37] = function()
    reg.flags.c = 1
    reg.flags.n = 0
    reg.flags.h = 0
  end

  -- nop
  opcodes[0x00] = function() end

  -- halt
  opcodes[0x76] = function()
    --if interrupts_enabled == 1 then
      --print("Halting!")
      z80.halted = 1
    --else
      --print("Interrupts not enabled! Not actually halting...")
    --end
  end

  -- stop
  opcodes[0x10] = function()
    -- The stop opcode should always, for unknown reasons, be followed
    -- by an 0x00 data byte. If it isn't, this may be a sign that the
    -- emulator has run off the deep end, and this isn't a real STOP
    -- instruction.
    -- TODO: Research real hardware's behavior in these cases
    local stop_value = read_nn()
    if stop_value == 0x00 then
      print("STOP instruction not followed by NOP!")
      --halted = 1
    else
      print("Unimplemented WEIRDNESS after 0x10")
    end

    if band(io.ram[0x4D], 0x01) ~= 0 then
      --speed switch!
      print("Switching speeds!")
      if double_speed then
        add_cycles = add_cycles_normal
        double_speed = false
        io.ram[0x4D] = band(io.ram[0x4D], 0x7E) + 0x00
        timers.set_normal_speed()
        print("Switched to Normal Speed")
      else
        add_cycles = add_cycles_double
        double_speed = true
        io.ram[0x4D] = band(io.ram[0x4D], 0x7E) + 0x80
        timers.set_double_speed()
        print("Switched to Double Speed")
      end
    end
  end

  -- di
  opcodes[0xF3] = function()
    interrupts.disable()
    --print("Disabled interrupts with DI")
  end
  -- ei
  opcodes[0xFB] = function()
    interrupts.enable()
    --print("Enabled interrupts with EI")
    z80.process_interrupts()
  end

  -- ====== GMB Jumpcommands ======
  jump_to_nnnn = function()
    local lower = read_nn()
    local upper = lshift(read_nn(), 8)
    reg.pc = upper + lower
  end

  -- jp nnnn
  opcodes[0xC3] = function()
    jump_to_nnnn()
    add_cycles(4)
  end

  -- jp HL
  opcodes[0xE9] = function()
    reg.pc = reg.hl()
  end

  -- jp nz, nnnn
  opcodes[0xC2] = function()
    if reg.flags.z == 0 then
      jump_to_nnnn()
      add_cycles(4)
    else
      reg.pc = reg.pc + 2
      add_cycles(8)
    end
  end

  -- jp nc, nnnn
  opcodes[0xD2] = function()
    if reg.flags.c == 0 then
      jump_to_nnnn()
      add_cycles(4)
    else
      reg.pc = reg.pc + 2
      add_cycles(8)
    end
  end

  -- jp z, nnnn
  opcodes[0xCA] = function()
    if reg.flags.z == 1 then
      jump_to_nnnn()
      add_cycles(4)
    else
      reg.pc = reg.pc + 2
      add_cycles(8)
    end
  end

  -- jp c, nnnn
  opcodes[0xDA] = function()
    if reg.flags.c == 1 then
      jump_to_nnnn()
      add_cycles(4)
    else
      reg.pc = reg.pc + 2
      add_cycles(8)
    end
  end

  function jump_relative_to_nn()
    local offset = read_nn()
    if offset > 127 then
      offset = offset - 256
    end
    reg.pc = band(reg.pc + offset, 0xFFFF)
  end

  -- jr nn
  opcodes[0x18] = function()
    jump_relative_to_nn()
    add_cycles(4)
  end

  -- jr nz, nn
  opcodes[0x20] = function()
    if reg.flags.z == 0 then
      jump_relative_to_nn()
    else
      reg.pc = reg.pc + 1
    end
    add_cycles(4)
  end

  -- jr nc, nn
  opcodes[0x30] = function()
    if reg.flags.c == 0 then
      jump_relative_to_nn()
    else
      reg.pc = reg.pc + 1
    end
    add_cycles(4)
  end

  -- jr z, nn
  opcodes[0x28] = function()
    if reg.flags.z == 1 then
      jump_relative_to_nn()
    else
      reg.pc = reg.pc + 1
    end
    add_cycles(4)
  end

  -- jr c, nn
  opcodes[0x38] = function()
    if reg.flags.c == 1 then
      jump_relative_to_nn()
    else
      reg.pc = reg.pc + 1
    end
    add_cycles(4)
  end

  call_nnnn = function()
    local lower = read_nn()
    local upper = read_nn() * 256
    -- at this point, reg.pc points at the next instruction after the call,
    -- so store the current PC to the stack

    reg.sp = (reg.sp + 0xFFFF) % 0x10000
    write_byte(reg.sp, rshift(reg.pc, 8))
    reg.sp = (reg.sp + 0xFFFF) % 0x10000
    write_byte(reg.sp, reg.pc % 0x100)

    reg.pc = upper + lower
  end

  -- call nn
  opcodes[0xCD] = function()
    call_nnnn()
    add_cycles(12)
  end

  -- call nz, nnnn
  opcodes[0xC4] = function()
    if reg.flags.z == 0 then
      call_nnnn()
      add_cycles(12)
    else
      reg.pc = reg.pc + 2
      add_cycles(8)
    end
  end

  -- call nc, nnnn
  opcodes[0xD4] = function()
    if reg.flags.c == 0 then
      call_nnnn()
      add_cycles(12)
    else
      reg.pc = reg.pc + 2
      add_cycles(8)
    end
  end

  -- call z, nnnn
  opcodes[0xCC] = function()
    if reg.flags.z == 1 then
      call_nnnn()
      add_cycles(12)
    else
      reg.pc = reg.pc + 2
      add_cycles(8)
    end
  end

  -- call c, nnnn
  opcodes[0xDC] = function()
    if reg.flags.c == 1 then
      call_nnnn()
      add_cycles(12)
    else
      reg.pc = reg.pc + 2
      add_cycles(8)
    end
  end

  local ret = function()
    local lower = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
    local upper = lshift(read_byte(reg.sp), 8)
    reg.sp = band(0xFFFF, reg.sp + 1)
    reg.pc = upper + lower
    add_cycles(12)
  end

  -- ret
  opcodes[0xC9] = function() ret() end

  -- ret nz
  opcodes[0xC0] = function()
    if reg.flags.z == 0 then
      ret()
    end
    add_cycles(4)
  end

  -- ret nc
  opcodes[0xD0] = function()
    if reg.flags.c == 0 then
      ret()
    end
    add_cycles(4)
  end

  -- ret nz
  opcodes[0xC8] = function()
    if reg.flags.z == 1 then
      ret()
    end
    add_cycles(4)
  end

  -- ret nz
  opcodes[0xD8] = function()
    if reg.flags.c == 1 then
      ret()
    end
    add_cycles(4)
  end

  -- reti
  opcodes[0xD9] = function()
    ret()
    interrupts.enable()
    z80.process_interrupts()
  end

  -- note: used only for the RST instructions below
  function call_address(address)
    -- reg.pc points at the next instruction after the call,
    -- so store the current PC to the stack
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, rshift(band(reg.pc, 0xFF00), 8))
    reg.sp = band(0xFFFF, reg.sp - 1)
    write_byte(reg.sp, band(reg.pc, 0xFF))

    reg.pc = address
    add_cycles(12)
  end

  -- rst N
  opcodes[0xC7] = function() call_address(0x00) end
  opcodes[0xCF] = function() call_address(0x08) end
  opcodes[0xD7] = function() call_address(0x10) end
  opcodes[0xDF] = function() call_address(0x18) end
  opcodes[0xE7] = function() call_address(0x20) end
  opcodes[0xEF] = function() call_address(0x28) end
  opcodes[0xF7] = function() call_address(0x30) end
  opcodes[0xFF] = function() call_address(0x38) end

  z80.process_interrupts = function()
    if interrupts.enabled ~= 0 then
      --local fired = band(memory[0xFFFF], memory[0xFF0F])
      local fired = band(io.ram[0xFF], io.ram[0x0F])
      if fired ~= 0 then
        -- an interrupt happened that we care about! How thoughtful

        -- First, disable interrupts so we don't have to pay royalties to Christopher Nolan
        interrupts.disable()

        -- If the processor is halted / stopped, re-start it
        z80.halted = 0

        -- Now, figure out which interrupt this is, and call the corresponding
        -- interrupt vector
        local vector = 0x40
        local count = 0
        while band(fired, 0x1) == 0 and count < 5 do
          vector = vector + 0x08
          fired = rshift(fired, 1)
          count = count + 1
        end
        -- we need to clear the corresponding bit first, to avoid infinite loops
        io.ram[0x0F] = bxor(lshift(0x1, count), io.ram[0x0F])
        call_address(vector)
        return true
      end
    end
    return false
  end

  -- For any opcodes that at this point are undefined,
  -- go ahead and "define" them with the following panic
  -- function
  function undefined_opcode()
    local opcode = read_byte(band(reg.pc - 1, 0xFFFF))
    print(string.format("Unhandled opcode!: %x", opcode))
  end

  for i = 0, 0xFF do
    if not opcodes[i] then
      opcodes[i] = undefined_opcode
    end
  end

  z80.process_instruction = function()
    --if profile_enabled then
    --  Pie:attach()
    --end

    --  If the processor is currently halted, then do nothing.
    if z80.halted == 0 then
      local opcode = read_byte(reg.pc)
      -- Advance to one byte beyond the opcode
      reg.pc = band(reg.pc + 1, 0xFFFF)
      -- Run the instruction
      opcodes[opcode]()
    end
    -- add a base clock of 4 to every instruction
    add_cycles(4)

    --if profile_enabled then
    --  Pie:detach()
    --end
    return true
  end

  function request_interrupt(bitmask)
    io.ram[0x0F] = band(bor(io.ram[0x0F], bitmask), 0x1F)
    if band(io.ram[0xFF], bitmask) ~= 0 then
      z80.halted = 0
    end
    z80.process_interrupts()
  end

  io.write_logic[io.ports.IF] = function(byte)
    io.ram[io.ports.IF] = byte
    if byte ~= 0 then
      z80.process_interrupts()
    end
  end

  io.write_logic[io.ports.IE] = function(byte)
    io.ram[io.ports.IE] = byte
    if byte ~= 0 then
      z80.process_interrupts()
    end
  end

  return z80
end

return Z80
