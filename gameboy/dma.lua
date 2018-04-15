local bit32 = require("bit")

local Dma = {}

function Dma.new(modules)
  local dma = {}

  local io = modules.io
  local memory = modules.memory
  local timers = modules.timers
  local ports = io.ports

  dma.source = 0
  dma.destination = 0
  dma.current = 0
  dma.length = 0
  dma.hblank = false
  dma.running = false

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

  io.write_logic[0x55] = function(byte)
    dma.source = bit32.lshift(io.ram[0x51], 8) + bit32.band(io.ram[0x52], 0xF0)
    dma.destination = bit32.lshift(bit32.band(io.ram[0x53], 0x1F), 8) + bit32.band(io.ram[0x54], 0xF0) + 0x8000
    dma.length = (bit32.band(byte, 0x7F) + 1) * 16
    if bit32.band(byte, 0x80) ~= 0 then
      dma.hblank = true
      print("HBlank DMA from ", dma.source, " to ", dma.destination)
    else
      dma.hblank = false
      -- process the DMA now, adjust clock too. (cheat, basically.)
      for i = 0, dma.length - 1 do
        memory[dma.destination + i] = memory[dma.source + i]
      end
      timers.system_clock = timers.system_clock + dma.length / 2
      io.ram[0x55] = 0xFF
      --print(string.format("General Purpose DMA From: %04X -> %04X Length: %04X", dma.source, dma.destination, dma.length))
    end
  end

  return dma
end

return Dma
