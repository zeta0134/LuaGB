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
local apply_rl_rr_cb = require("gameboy/z80/rl_rr_cb")
local apply_stack = require("gameboy/z80/stack")

local Registers = require("gameboy/z80/registers")

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

  z80.registers = Registers.new()
  local reg = z80.registers

  -- Intentionally bad naming convention: I am NOT typing "registers"
  -- a bazillion times. The exported symbol uses the full name as a
  -- reasonable compromise.
  z80.halted = 0

  local add_cycles_normal = function(cycles)
    timers.system_clock = timers.system_clock + cycles
  end

  local add_cycles_double = function(cycles)
    timers.system_clock = timers.system_clock + cycles / 2
  end

  z80.add_cycles = add_cycles_normal
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
    z80.add_cycles = add_cycles_normal
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
  apply_rl_rr_cb(opcodes, opcode_cycles, z80, memory)
  apply_stack(opcodes, opcode_cycles, z80, memory)


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
        z80.add_cycles = add_cycles_normal
        double_speed = false
        io.ram[0x4D] = band(io.ram[0x4D], 0x7E) + 0x00
        timers.set_normal_speed()
        print("Switched to Normal Speed")
      else
        add_cycles = add_cycles_double
        z80.add_cycles = add_cycles_double
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
    z80.service_interrupt()
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
    z80.service_interrupt()
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

  z80.service_interrupt = function()
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
  interrupts.service_handler = z80.service_interrupt

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
