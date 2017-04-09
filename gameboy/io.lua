local bit32 = require("bit")

local Io = {}

function Io.new(modules)
  local io = {}

  local memory = modules.memory

  local ports = {}
  -- Port names pulled from Pan Docs, starting here:
  -- http://bgb.bircd.org/pandocs.htm#videodisplay

  -- LCD Control
  ports.LCDC = 0x40

  -- LCD Status
  ports.STAT = 0x41

  -- BG Scroll
  ports.SCY = 0x42
  ports.SCX = 0x43

  -- Current Scanline (LCDC Y-coordinate)
  ports.LY = 0x44
  -- LCD Compare, scanline on which a STAT interrupt is requested
  ports.LYC = 0x45

  -- B&W Palettes
  ports.BGP = 0x47
  ports.OBP0 = 0x48
  ports.OBP1 = 0x49

  -- Window Scroll
  ports.WY = 0x4A
  ports.WX = 0x4B

  -- Color-mode Palettes
  ports.BGPI = 0x68
  ports.BGPD = 0x69
  ports.OBPI = 0x6A
  ports.OBPD = 0x6B

  -- Color-mode VRAM Bank
  ports.VBK = 0x4F

  -- DMA Transfer Start (Write Only)
  ports.DMA = 0x46

  -- Joypad
  ports.JOYP = 0x00

  -- Timers
  ports.DIV = 0x04
  ports.TIMA = 0x05
  ports.TMA = 0x06
  ports.TAC = 0x07

  -- Interrupts
  ports.IE = 0xFF
  ports.IF = 0x0F

  -- Sound
  ports.NR10 = 0x10
  ports.NR11 = 0x11
  ports.NR12 = 0x12
  ports.NR13 = 0x13
  ports.NR14 = 0x14

  ports.NR21 = 0x16
  ports.NR22 = 0x17
  ports.NR23 = 0x18
  ports.NR24 = 0x19

  ports.NR30 = 0x1A
  ports.NR31 = 0x1B
  ports.NR32 = 0x1C
  ports.NR33 = 0x1D
  ports.NR34 = 0x1E

  ports.NR41 = 0x20
  ports.NR42 = 0x21
  ports.NR43 = 0x22
  ports.NR44 = 0x23

  ports.NR50 = 0x24
  ports.NR51 = 0x25
  ports.NR52 = 0x26

  io.ports = ports


  io.write_logic = {}
  io.read_logic = {}
  io.write_mask = {}

  io.ram = memory.generate_block(0x100)
  io.block = {}
  io.block.mt = {}
  io.block.mt.__index = function(table, address)
    address = address - 0xFF00
    if io.read_logic[address] then
      return io.read_logic[address]()
    else
      return io.ram[address]
    end
  end

  io.write_mask[ports.JOYP] = 0x30
  io.write_mask[ports.LY] = 0x00

  io.write_logic[0x70] = function(byte)
    if io.gameboy.type == io.gameboy.types.color then
      io.ram[0x70] = bit32.band(0x7, byte)
      memory.work_ram_1.bank = bit32.band(0x7, byte)
      if memory.work_ram_1.bank == 0 then
        memory.work_ram_1.bank = 1
      end
    else
      -- Not sure if the write mask should apply in DMG / SGB mode
      io.ram[0x70] = byte
    end
  end

  io.block.mt.__newindex = function(table, address, value)
    address = address - 0xFF00
    if io.write_mask[address] then
      local masked_value = bit32.band(value, io.write_mask[address])
      local masked_memory = bit32.band(io.ram[address], bit32.bnot(io.write_mask[address]))
      value = masked_value + masked_memory
    end
    if io.write_logic[address] then
      -- Some addresses (mostly IO ports) have fancy logic or do strange things on
      -- writes, so we handle those here.
      io.write_logic[address](value)
      return
    end
    io.ram[address] = value
  end

  io.reset = function(gameboy)
    io.gameboy = gameboy

    for i = 0, #io.ram do
      io.ram[i] = 0
    end

    -- Set io registers to post power-on values
    -- Sound Enable must be set to F1
    io.ram[0x26] = 0xF1

    io.ram[ports.LCDC] = 0x91
    io.ram[ports.BGP ] = 0xFC
    io.ram[ports.OBP0] = 0xFF
    io.ram[ports.OBP1] = 0xFF
  end

  io.save_state = function()
    local state = {}

    for i = 0, 0xFF do
      state[i] = io.ram[i]
    end

    return state
  end

  io.load_state = function(state)
    for i = 0, 0xFF do
      io.ram[i] = state[i]
    end
  end

  setmetatable(io.block, io.block.mt)
  memory.map_block(0xFF, 0xFF, io.block, 0)

  return io
end

return Io
