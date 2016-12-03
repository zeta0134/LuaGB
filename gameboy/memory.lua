local memory = {}

memory.write_mask = {}
memory.write_mask[0xFF00] = 0x30
memory.write_mask[0xFF41] = 0x78
memory.write_mask[0xFF44] = 0x00

memory.read_logic = {}
memory.read_logic[0xFF04] = function()
  --print("Read from DIV")
  return memory[0xFF04]
end

memory.read_logic[0xFF05] = function()
  --print("Read from TIMA")
  return memory[0xFF05]
end

memory.write_logic = {}
memory.write_logic[0xFF04] = function(byte)
  -- Timer DIV register; any write resets this value to 0
  memory[0xFF04] = 0
end

memory.write_logic[0xFF44] = function(byte)
  -- LY, writes reset the counter
  memory[0xFF44] = 0
end

memory.write_logic[0xFF46] = function(byte)
  -- DMA Transfer. Copies data from 0x0000 + 0x100 * byte, into OAM data
  local source = 0x0000 + 0x100 * byte
  local destination = 0xFE00
  while destination <= 0xFE9F do
    memory[destination] = memory[source]
    destination = destination + 1
    source = source + 1
  end
  -- TODO: Implement memory access cooldown; real hardware requires
  -- programs to call DMA transfer from High RAM and then wait there
  -- for several clocks while it finishes.
end

memory.read_byte = function(address)
  if memory.read_logic[address] then
    return memory.read_logic[address]()
  end
  -- todo: make this respect memory regions
  -- and VRAM / OAM access limits.
  -- Also, cart bank switching would be cool.
  return memory[bit32.band(address, 0xFFFF)]
end

--TODO: After implementing proper mapping blocks, remove this / handle this
--logic as part of the graphics / VRAM subsystem instead.
graphics = {}
graphics.Status = {}
graphics.Status.Mode = function()
  return bit32.band(memory[0xFF41], 0x3)
end

memory.write_byte = function(address, byte)
  if memory.write_mask[address] then
    byte = bit32.band(byte, memory.write_mask[address]) + bit32.band(memory[address], bit32.bnot(memory.write_mask[address]))
  end
  if memory.write_logic[address] then
    -- Some addresses (mostly IO ports) have fancy logic or do strange things on
    -- writes, so we handle those here.
    memory.write_logic[address](byte)
    return
  end
  if address <= 0x7FFF then
    -- ROM area; we should not actually write data here, but should
    -- handle some special case addresses
    -- TODO: Handle bank switching logic here.
  elseif address >= 0x8000 and address <= 0x9FFF and graphics.Status.Mode() == 3 then
    -- silently discard this write; the GPU has exclusive access to VRAM
    -- during this time

    --debug: or not
    memory[bit32.band(address, 0xFFFF)] = bit32.band(byte, 0xFF)
  elseif address >= 0xFE00 and address <= 0xFE9F and graphics.Status.Mode() >= 2 and graphics.Status.Mode() <= 3 then
    -- silently discard this write; the GPU has exclusive access to OAM memory

    --debug: or not
    memory[bit32.band(address, 0xFFFF)] = bit32.band(byte, 0xFF)
  else
    -- default case: simple write please.
    memory[bit32.band(address, 0xFFFF)] = bit32.band(byte, 0xFF)
  end
end

memory.initialize = function()
  for i = 0, 0xFFFF do
    memory[i] = 0
  end

  -- write out default starting states for IO registers
  -- skipping sound for now
  memory[0xFF26] = 0xF1
  memory[0xFF40] = 0x91
  memory[0xFF47] = 0xFC
  memory[0xFF48] = 0xFF
  memory[0xFF49] = 0xFF
end

return memory
