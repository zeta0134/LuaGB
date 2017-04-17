local bit32 = require("bit")

local lshift = bit32.lshift
local rshift = bit32.rshift
local band = bit32.band
local bxor = bit32.bxor
local bor = bit32.bor
local bnor = bit32.bnor

function apply(opcodes, opcode_cycles, z80, memory)
  local read_nn = z80.read_nn
  local reg = z80.registers
  local flags = reg.flags

  local read_byte = memory.read_byte
  local write_byte = memory.write_byte

  local add_cycles = z80.add_cycles

  -- ====== GMB Rotate and Shift Commands ======
  local reg_rlc = function(value)
    value = lshift(value, 1)
    -- move what would be bit 8 into the carry
    flags.c = band(value, 0x100) ~= 0
    value = band(value, 0xFF)
    -- also copy the carry into bit 0
    if flags.c then
      value = value + 1
    end
    flags.z = value == 0
    flags.h = false
    flags.n = false
    return value
  end

  local reg_rl = function(value)
    value = lshift(value, 1)
    -- move the carry into bit 0
    if flags.c then
      value = value + 1
    end
    -- now move what would be bit 8 into the carry
    flags.c = band(value, 0x100) ~= 0
    value = band(value, 0xFF)

    flags.z = value == 0
    flags.h = false
    flags.n = false
    return value
  end

  local reg_rrc = function(value)
    -- move bit 0 into the carry
    flags.c = band(value, 0x1) ~= 0
    value = rshift(value, 1)
    -- also copy the carry into bit 7
    if flags.c then
      value = value + 0x80
    end
    flags.z = value == 0
    flags.h = false
    flags.n = false
    return value
  end

  local reg_rr = function(value)
    -- first, copy the carry into bit 8 (!!)
    if flags.c then
      value = value + 0x100
    end
    -- move bit 0 into the carry
    flags.c = band(value, 0x1) ~= 0
    value = rshift(value, 1)
    -- for safety, this should be a nop?
    -- value = band(value, 0xFF)
    flags.z = value == 0
    flags.h = false
    flags.n = false
    return value
  end

  -- rlc a
  opcodes[0x07] = function() reg.a = reg_rlc(reg.a); flags.z = false end

  -- rl a
  opcodes[0x17] = function() reg.a = reg_rl(reg.a); flags.z = false end

  -- rrc a
  opcodes[0x0F] = function() reg.a = reg_rrc(reg.a); flags.z = false end

  -- rr a
  opcodes[0x1F] = function() reg.a = reg_rr(reg.a); flags.z = false end

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

  local reg_sla = function(value)
    -- copy bit 7 into carry
    flags.c = band(value, 0x80) == 0x80
    value = band(lshift(value, 1), 0xFF)
    flags.z = value == 0
    flags.h = false
    flags.n = false
    add_cycles(4)
    return value
  end

  local reg_srl = function(value)
    -- copy bit 0 into carry
    flags.c = band(value, 0x1) == 1
    value = rshift(value, 1)
    flags.z = value == 0
    flags.h = false
    flags.n = false
    add_cycles(4)
    return value
  end

  local reg_sra = function(value)
    local arith_value = reg_srl(value)
    -- if bit 6 is set, copy it to bit 7
    if band(arith_value, 0x40) ~= 0 then
      arith_value = arith_value + 0x80
    end
    add_cycles(4)
    return arith_value
  end

  local reg_swap = function(value)
    value = rshift(band(value, 0xF0), 4) + lshift(band(value, 0xF), 4)
    flags.z = value == 0
    flags.n = false
    flags.h = false
    flags.c = false
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

  -- ====== GMB Singlebit Operation Commands ======
  local reg_bit = function(value, bit)
    flags.z = band(value, lshift(0x1, bit)) == 0
    flags.n = false
    flags.h = true
    return
  end

  opcodes[0xCB] = function()
    local cb_op = read_nn()
    add_cycles(4)
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
end

return apply
