local memory = {}

local blocks = {}

memory.map_block = function(starting_address, ending_address, block)
  local new_block = {}
  new_block.starting_address = starting_address
  new_block.ending_address = ending_address
  new_block.data = block
  blocks[#blocks + 1] = new_block
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
memory.map_block(0xC000, 0xCFFF, work_ram_0)
memory.map_block(0xD000, 0xDFFF, work_ram_1)

local work_ram_echo = {}
work_ram_echo.mt = {}
work_ram_echo.__index = function(table, key)
  memory.read_byte(key - 0x2000)
end
work_ram_echo.__newindex = function(table, key, value)
  memory.write_byte(key - 0x2000, value)
end
setmetatable(work_ram_echo, work_ram_echo.mt)
memory.map_block(0xE000, 0xFDFF, work_ram_echo)

-- High RAM (and Interrupt Enable Register)
local high_ram = memory.generate_block(0x80)
memory.map_block(0xFF80, 0xFFFF, high_ram)

memory.read_byte = function(address)
  for b = 1, #blocks do
    if blocks[b].starting_address <= address and blocks[b].ending_address >= address then
      return blocks[b].data[bit32.band(address - blocks[b].starting_address, 0xFFFF)]
    end
  end
  -- No mapped block for this memory exists! Return something sane-ish.
  -- TODO: Research what real hardware does on unmapped memory regions and
  -- do that here instead.
  return 0x00
end

memory.write_byte = function(address, byte)
  --print("Writing: " .. address)
  for b = 1, #blocks do
    if blocks[b].starting_address <= address and blocks[b].ending_address >= address then
      blocks[b].data[bit32.band(address - blocks[b].starting_address, 0xFFFF)] = bit32.band(byte, 0xFF)
      return
    end
  end
  -- Note: If no memory is mapped to handle this write, DO NOTHING. (This is fine.)
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

  -- spit out the mappings please
  print("Mapped blocks: ")
  for b = 1, #blocks do
    print(string.format("%x - %x", blocks[b].starting_address, blocks[b].ending_address))
  end
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
