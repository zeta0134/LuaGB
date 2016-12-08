memory = require("gameboy/memory")

io = {}

io.ram = memory.generate_block(0x100)
io.block = {}
io.block.mt = {}
io.block.mt.__index = function(table, key)
  return io.ram[key]
end

io.write_mask = {}
io.write_mask[0x00] = 0x30
io.write_mask[0x41] = 0x78
io.write_mask[0x44] = 0x00

io.write_logic = {}
io.write_logic[0x04] = function(byte)
  -- Timer DIV register; any write resets this value to 0
  io.ram[0x04] = 0
end

io.write_logic[0x44] = function(byte)
  -- LY, writes reset the counter
  io.ram[0x44] = 0
end

io.write_logic[0x46] = function(byte)
  -- DMA Transfer. Copies data from 0x0000 + 0x100 * byte, into OAM data
  local source = 0x0000 + 0x100 * byte
  local destination = 0xFE00
  while destination <= 0xFE9F do
    memory.write_byte(destination, memory.read_byte(source))
    destination = destination + 1
    source = source + 1
  end
  -- TODO: Implement memory access cooldown; real hardware requires
  -- programs to call DMA transfer from High RAM and then wait there
  -- for several clocks while it finishes.
end

io.block.mt.__newindex = function(table, address, value)
  if io.write_mask[address] then
    value = bit32.band(value, io.write_mask[address]) + bit32.band(memory[address], bit32.bnot(io.write_mask[address]))
  end
  if io.write_logic[address] then
    -- Some addresses (mostly IO ports) have fancy logic or do strange things on
    -- writes, so we handle those here.
    io.write_logic[address](value)
    return
  end
  io.ram[address] = value
end

setmetatable(io.block, io.block.mt)
memory.map_block(0xFF, 0xFF, io.block)

return io
