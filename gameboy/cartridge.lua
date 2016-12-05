memory = require("gameboy/memory")

local cartridge = {}

-- TODO: Implement MBC logic here, please

-- Simplest possible case: Ignore everything, and
local cartridge_bank_0 = memory.generate_block(16 * 1024)
memory.map_block(0x0000, 0x3FFF, cartridge_bank_0)
local cartridge_bank_1 = memory.generate_block(16 * 1024)
memory.map_block(0x4000, 0x7FFF, cartridge_bank_1)

local external_ram = memory.generate_block(8 * 1024)
memory.map_block(0xA000, 0xBFFF, external_ram)

cartridge.load = function(file_data, size)
  print("Reading cartridge into memory...")
  cartridge.raw_data = {}
  for i = 0, size - 1 do
    cartridge.raw_data[i] = file_data:byte(i + 1)
  end
  print("Read " .. math.ceil(#cartridge.raw_data / 1024) .. " kB")
  print_cartridge_header(cartridge.raw_data)

  -- TODO: Not this please.
  print("Copying cart data into lower 0x7FFF of main memory...")
  for i = 0, 0x7FFF do
    memory[i] = cartridge.raw_data[i]
  end
end

return cartridge
