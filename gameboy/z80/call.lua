local bit32 = require("bit")

local lshift = bit32.lshift
local rshift = bit32.rshift
local band = bit32.band
local bxor = bit32.bxor
local bor = bit32.bor
local bnor = bit32.bnor

function apply(opcodes, opcode_cycles, z80, memory, interrupts)
  local read_nn = z80.read_nn
  local reg = z80.registers
  local flags = reg.flags

  local read_byte = memory.read_byte
  local write_byte = memory.write_byte

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
  opcode_cycles[0xCD] = 24
  opcodes[0xCD] = function()
    call_nnnn()
  end

  -- call nz, nnnn
  opcode_cycles[0xC4] = 12
  opcodes[0xC4] = function()
    if not flags.z then
      call_nnnn()
      z80.add_cycles(12)
    else
      reg.pc = reg.pc + 2
    end
  end

  -- call nc, nnnn
  opcode_cycles[0xD4] = 12
  opcodes[0xD4] = function()
    if not flags.c then
      call_nnnn()
      z80.add_cycles(12)
    else
      reg.pc = reg.pc + 2
    end
  end

  -- call z, nnnn
  opcode_cycles[0xCC] = 12
  opcodes[0xCC] = function()
    if flags.z then
      call_nnnn()
      z80.add_cycles(12)
    else
      reg.pc = reg.pc + 2
    end
  end

  -- call c, nnnn
  opcode_cycles[0xDC] = 12
  opcodes[0xDC] = function()
    if flags.c then
      call_nnnn()
      z80.add_cycles(12)
    else
      reg.pc = reg.pc + 2
    end
  end

  local ret = function()
    local lower = read_byte(reg.sp)
    reg.sp = band(0xFFFF, reg.sp + 1)
    local upper = lshift(read_byte(reg.sp), 8)
    reg.sp = band(0xFFFF, reg.sp + 1)
    reg.pc = upper + lower
    z80.add_cycles(12)
  end

  -- ret
  opcodes[0xC9] = function() ret() end

  -- ret nz
  opcode_cycles[0xC0] = 8
  opcodes[0xC0] = function()
    if not flags.z then
      ret()
    end
  end

  -- ret nc
  opcode_cycles[0xD0] = 8
  opcodes[0xD0] = function()
    if not flags.c then
      ret()
    end
  end

  -- ret z
  opcode_cycles[0xC8] = 8
  opcodes[0xC8] = function()
    if flags.z then
      ret()
    end
  end

  -- ret c
  opcode_cycles[0xD8] = 8
  opcodes[0xD8] = function()
    if flags.c then
      ret()
    end
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
  end

  -- rst N
  opcode_cycles[0xC7] = 16
  opcodes[0xC7] = function() call_address(0x00) end

  opcode_cycles[0xCF] = 16
  opcodes[0xCF] = function() call_address(0x08) end

  opcode_cycles[0xD7] = 16
  opcodes[0xD7] = function() call_address(0x10) end

  opcode_cycles[0xDF] = 16
  opcodes[0xDF] = function() call_address(0x18) end

  opcode_cycles[0xE7] = 16
  opcodes[0xE7] = function() call_address(0x20) end

  opcode_cycles[0xEF] = 16
  opcodes[0xEF] = function() call_address(0x28) end

  opcode_cycles[0xF7] = 16
  opcodes[0xF7] = function() call_address(0x30) end

  opcode_cycles[0xFF] = 16
  opcodes[0xFF] = function() call_address(0x38) end
end

return apply
