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

  -- ====== GMB Jumpcommands ======
  local jump_to_nnnn = function()
    local lower = read_nn()
    local upper = lshift(read_nn(), 8)
    reg.pc = upper + lower
  end

  -- jp nnnn
  opcode_cycles[0xC3] = 16
  opcodes[0xC3] = function()
    jump_to_nnnn()
  end

  -- jp HL
  opcodes[0xE9] = function()
    reg.pc = reg.hl()
  end

  -- jp nz, nnnn
  opcode_cycles[0xC2] = 16
  opcodes[0xC2] = function()
    if not flags.z then
      jump_to_nnnn()
    else
      reg.pc = reg.pc + 2
      z80.add_cycles(-4)
    end
  end

  -- jp nc, nnnn
  opcode_cycles[0xD2] = 16
  opcodes[0xD2] = function()
    if not flags.c then
      jump_to_nnnn()
    else
      reg.pc = reg.pc + 2
      z80.add_cycles(-4)
    end
  end

  -- jp z, nnnn
  opcode_cycles[0xCA] = 16
  opcodes[0xCA] = function()
    if flags.z then
      jump_to_nnnn()
    else
      reg.pc = reg.pc + 2
      z80.add_cycles(-4)
    end
  end

  -- jp c, nnnn
  opcode_cycles[0xDA] = 16
  opcodes[0xDA] = function()
    if flags.c then
      jump_to_nnnn()
    else
      reg.pc = reg.pc + 2
      z80.add_cycles(-4)
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
  opcode_cycles[0x18] = 12
  opcodes[0x18] = function()
    jump_relative_to_nn()
  end

  -- jr nz, nn
  opcode_cycles[0x20] = 12
  opcodes[0x20] = function()
    if not flags.z then
      jump_relative_to_nn()
    else
      reg.pc = reg.pc + 1
      z80.add_cycles(-4)
    end
  end

  -- jr nc, nn
  opcode_cycles[0x30] = 12
  opcodes[0x30] = function()
    if not flags.c then
      jump_relative_to_nn()
    else
      reg.pc = reg.pc + 1
      z80.add_cycles(-4)
    end
  end

  -- jr z, nn
  opcode_cycles[0x28] = 12
  opcodes[0x28] = function()
    if flags.z then
      jump_relative_to_nn()
    else
      reg.pc = reg.pc + 1
      z80.add_cycles(-4)
    end
  end

  -- jr c, nn
  opcode_cycles[0x38] = 12
  opcodes[0x38] = function()
    if flags.c then
      jump_relative_to_nn()
    else
      reg.pc = reg.pc + 1
      z80.add_cycles(-4)
    end
  end
end

return apply
