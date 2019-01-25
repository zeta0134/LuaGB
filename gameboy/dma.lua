local bit32 = require("bit")

local Dma = {}

function Dma.new(modules)
  local dma = {}

  local io = modules.io
  local memory = modules.memory
  local timers = modules.timers
  local ports = io.ports

  dma.source = 0
  dma.destination = 0x8000
  dma.current = 0
  dma.length = 0
  dma.hblank = false
  dma.running = false

  dma.do_hblank = function()
    if dma.hblank then
      for i = 0, 0x10 - 1 do
        memory[dma.destination + i] = memory[dma.source + i]
      end
      dma.source = dma.source + 0x10;
      dma.destination = dma.destination + 0x10;
      dma.length = dma.length - 0x10;
      --print(string.format("HBlank Transfer of 0x10 bytes from %04X to %04X", dma.source, dma.destination))
      if dma.length <= 0 then
        dma.hblank = false
        io.ram[0x55] = 0xFF;
        --print("HBlank transfer finished!");
      else
        io.ram[0x55] = (dma.length / 0x10) - 1;
      end
      -- TODO: Implement clock delay for hblank DMA transfers
    end
  end

  io.write_logic[ports.DMA] = function(byte)
    -- DMA Transfer. Copies data from 0x0000 + 0x100 * byte, into OAM data
    local destmap = memory.block_map[0xfe00]
    local sourcemap = memory.block_map[byte * 0x100]
    local source = 0x0000 + 0x100 * byte
    local destination = 0xFE00
    while destination <= 0xFE9F do
      destmap[destination] = sourcemap[source]
      destination = destination + 1
      source = source + 1
    end
    -- TODO: Implement memory access cooldown; real hardware requires
    -- programs to call DMA transfer from High RAM and then wait there
    -- for several clocks while it finishes.
  end

  io.write_logic[0x51] = function(byte)
    -- DMA source HIGH Byte
    dma.source = bit32.lshift(byte, 8) + bit32.band(dma.source, 0xFF)
  end

  io.write_logic[0x52] = function(byte)
    -- DMA source LOW byte (lower 4 bits ignored, forces alignment to 0x10
    dma.source = bit32.band(dma.source, 0xFF00) + bit32.band(byte, 0xF0)
  end

  io.write_logic[0x53] = function(byte)
    -- DMA destination HIGH byte (upper 3 bits ignored, forced to reside within 0x8000 - 0x9FFF)
    dma.destination = 0x8000 + bit32.lshift(bit32.band(byte, 0x1F), 8) + bit32.band(dma.destination, 0xFF)
  end

  io.write_logic[0x54] = function(byte)
    -- DMA destination LOW byte (lower 4 bits ignored, forces alignment to 0x10
    dma.destination = bit32.band(dma.destination, 0xFF00) + bit32.band(byte, 0xF0)
  end

  io.write_logic[0x55] = function(byte)
    --dma.source = bit32.lshift(io.ram[0x51], 8) + bit32.band(io.ram[0x52], 0xF0)
    --dma.destination = bit32.lshift(bit32.band(io.ram[0x53], 0x1F), 8) + bit32.band(io.ram[0x54], 0xF0) + 0x8000
    dma.length = (bit32.band(byte, 0x7F) + 1) * 16
    if bit32.band(byte, 0x80) ~= 0 then
      dma.hblank = true
      io.ram[0x55] = bit32.band(byte, 0x7F)
      --print(string.format("HBlank DMA from 0x%04X to 0x%04X with length 0x%04X", dma.source, dma.destination, dma.length))
      -- is the screen off, or are we in the middle of hblank? If so, copy a block right away
      current_mode = bit32.band(io.ram[ports.STAT], 0x3)
      display_disabled = bit32.band(io.ram[ports.LCDC], 0x80) == 0
      if current_mode == 0 or display_disabled then
        dma.do_hblank()
      end
    else
      if dma.hblank then
        --print("Stopped an HBlank DMA in progress!")
        -- Terminate the hblank DMA in progress. Do NOT start a general purpose DMA on this write.
        dma.hblank = false
        io.ram[0x55] = bit32.bor(io.ram[0x55], 0x80);
        return
      end
      dma.hblank = false
      -- process the DMA now, adjust clock too. (cheat, basically.)
      for i = 0, dma.length - 1 do
        memory[dma.destination + i] = memory[dma.source + i]
      end
      dma.destination = dma.destination + dma.length

      timers.system_clock = timers.system_clock + dma.length / 2
      io.ram[0x55] = 0xFF
      --print(string.format("General Purpose DMA From: %04X -> %04X Length: %04X", dma.source, dma.destination, dma.length))
    end
  end

  return dma
end

return Dma
