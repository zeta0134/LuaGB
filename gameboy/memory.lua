local memory = {}

local block_map = {}

memory.print_block_map = function()
  --debug
  print("Block Map: ")
  for b = 0, 0xFF do
    if block_map[b] then
      print(string.format("Block at: %02X starts at %04X", b, block_map[b].start))
    end
  end
end

memory.map_block = function(starting_high_byte, ending_high_byte, mapped_block, starting_address)
  if starting_high_byte > 0xFF or ending_high_byte > 0xFF then
    print("Bad block, bailing", starting_high_byte, ending_high_byte)
    return
  end

  starting_address = starting_address or bit32.lshift(starting_high_byte, 8)
  for i = starting_high_byte, ending_high_byte do
    block_map[bit32.lshift(i, 8)] = {start=starting_address, block=mapped_block}
  end
end

memory.generate_block = function(size)
  local block = {}
  for i = 0, size - 1 do
    block[i] = 0
  end
  return block
end

-- Main Memory
local work_ram_0 = memory.generate_block(4 * 1024)
local work_ram_1 = memory.generate_block(4 * 1024)
memory.map_block(0xC0, 0xCF, work_ram_0)
memory.map_block(0xD0, 0xDF, work_ram_1)

local work_ram_echo = {}
work_ram_echo.mt = {}
work_ram_echo.mt.__index = function(table, key)
  return memory.read_byte(key + 0xC000)
end
work_ram_echo.mt.__newindex = function(table, key, value)
  memory.write_byte(key + 0xC000, value)
end
setmetatable(work_ram_echo, work_ram_echo.mt)
memory.map_block(0xE0, 0xFD, work_ram_echo)

memory.read_byte = function(address)
  local high_byte = bit32.band(address, 0xFF00)
  if block_map[high_byte] then
    local adjusted_address = address - block_map[high_byte].start
    return block_map[high_byte].block[adjusted_address]
  end

  -- No mapped block for this memory exists! Return something sane-ish.
  -- TODO: Research what real hardware does on unmapped memory regions and
  -- do that here instead.
  return 0x00
end

memory.write_byte = function(address, byte)
  local high_byte = bit32.band(address, 0xFF00)
  if block_map[high_byte] then
    local adjusted_address = address - block_map[high_byte].start
    block_map[high_byte].block[adjusted_address] = byte
  end

  -- Note: If no memory is mapped to handle this write, DO NOTHING. (This is fine.)
end

memory.initialize = function()
  -- write out default starting states for IO registers
  -- skipping sound for now
  memory[0xFF26] = 0xF1
  memory[0xFF40] = 0x91
  memory[0xFF47] = 0xFC
  memory[0xFF48] = 0xFF
  memory[0xFF49] = 0xFF
end

-- Fancy: make access to ourselves act as an array, reading / writing memory using the above
-- logic. This should cause memory[address] to behave just as it would on hardware.
memory.mt = {}
memory.mt.__index = function(table, key)
  return memory.read_byte(key)
end
memory.mt.__newindex = function(table, key, value)
  memory.write_byte(key, value)
end
setmetatable(memory, memory.mt)

return memory
