local bit32 = require("bit")

local lshift = bit32.lshift
local rshift = bit32.rshift
local band = bit32.band
local bxor = bit32.bxor
local bor = bit32.bor
local bnot = bit32.bnot

local apply_arithmetic = require("gameboy/z80/arithmetic")
local apply_bitwise = require("gameboy/z80/bitwise")
local apply_cp = require("gameboy/z80/cp")
local apply_inc_dec = require("gameboy/z80/inc_dec")
local apply_ld = require("gameboy/z80/ld")
local apply_stack = require("gameboy/z80/stack")


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
    -- Initialize registers to what the GB's
    -- iternal state would be after executing
    -- BIOS code

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
  local opcode_cycles = {}
  local opcode_names = {}

  -- Initialize the opcode_cycles table with 4 as a base cycle, so we only
  -- need to care about variations going forward
  for i = 0x00, 0xFF do
    opcode_cycles[i] = 4
  end

  function z80.read_at_hl()
    add_cycles(4)
    return read_byte(reg.hl())
  end

  function z80.set_at_hl(value)
    add_cycles(4)
    write_byte(reg.hl(), value)
  end

  function z80.read_nn()
    local nn = read_byte(reg.pc)
    reg.pc = reg.pc + 1
    add_cycles(4)
    return nn
  end

  local read_at_hl = z80.read_at_hl
  local set_at_hl = z80.set_at_hl
  local read_nn = z80.read_nn

  apply_arithmetic(opcodes, opcode_cycles, z80, memory)
  apply_bitwise(opcodes, opcode_cycles, z80, memory)
  apply_cp(opcodes, opcode_cycles, z80, memory)
  apply_inc_dec(opcodes, opcode_cycles, z80, memory)
  apply_ld(opcodes, opcode_cycles, z80, memory)
  apply_stack(opcodes, opcode_cycles, z80, memory)

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

  local reg_sla = function(value)
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

  local reg_srl = function(value)
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
  local reg_bit = function(value, bit)
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
  local jump_to_nnnn = function()
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

  local function jump_relative_to_nn()
    local offset = read_nn()
    if offset > 127 then
      offset = offset - 256
    end
    reg.pc = (reg.pc + offset) % 0x10000
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

  local call_nnnn = function()
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
  local function call_address(address)
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
    local fired = band(io.ram[0xFF], io.ram[0x0F])
    if fired ~= 0 then
      z80.halted = 0
      if interrupts.enabled ~= 0 then
        -- First, disable interrupts to prevent nesting routines (unless the program explicitly re-enables them later)
        interrupts.disable()

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

  -- register this as a callback with the interrupts module
  interrupts.request_callback = z80.process_interrupts

  -- For any opcodes that at this point are undefined,
  -- go ahead and "define" them with the following panic
  -- function
  local function undefined_opcode()
    local opcode = read_byte(band(reg.pc - 1, 0xFFFF))
    print(string.format("Unhandled opcode!: %x", opcode))
  end

  for i = 0, 0xFF do
    if not opcodes[i] then
      opcodes[i] = undefined_opcode
    end
  end

  z80.process_instruction = function()
    --  If the processor is currently halted, then do nothing.
    if z80.halted == 0 then
      local opcode = read_byte(reg.pc)
      -- Advance to one byte beyond the opcode
      reg.pc = band(reg.pc + 1, 0xFFFF)
      -- Run the instruction
      opcodes[opcode]()

      -- add a base clock of 4 to every instruction
      -- NOPE, working on removing add_cycles, pull from the opcode_cycles
      -- table instead
      add_cycles(opcode_cycles[opcode])
    else
      -- Base cycles of 4 when halted, for sanity
      add_cycles(4)
    end

    return true
  end

  return z80
end

return Z80
