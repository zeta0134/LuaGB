local memory = require("gameboy/memory")
local rom_header = require("gameboy/rom_header")

local cartridge = {}

-- TODO: Implement MBC logic here, please

-- Simplest possible case: Ignore everything, and
--local cartridge_bank_0 = memory.generate_block(16 * 1024)
--memory.map_block(0x0000, 0x3FFF, cartridge_bank_0)
--local cartridge_bank_1 = memory.generate_block(16 * 1024)
--memory.map_block(0x4000, 0x7FFF, cartridge_bank_1)

local external_ram = memory.generate_block(32 * 1024)

-- Very simple: Map the entire 32k cartridge into lower memory, and be done with it.
local mbc_none = {}
mbc_none.mt = {}
mbc_none.mt.__index = function(table, address)
  --print("Request read at: ", address)
  return cartridge.raw_data[address]
end
mbc_none.mt.__newindex = function(table, address, value)
  --do nothing!
  return
end
setmetatable(mbc_none, mbc_none.mt)

local mbc1 = {}
mbc1.rom_bank = 0
mbc1.ram_bank = 0
mbc1.mode = 0 --0 = ROM bank mode, 1 = RAM bank mode
mbc1.ram_enable = false
mbc1.mt = {}
mbc1.mt.__index = function(table, address)
  -- Lower 16k: return the first bank, always
  if address <= 0x3FFF then
    return cartridge.raw_data[address]
  end
  -- Upper 16k: return the currently selected bank
  if address >= 0x4000 and address <= 0x7FFF then
    local rom_bank = mbc1.rom_bank
    if mbc1.mode == 0 then
      rom_bank = rom_bank + bit32.lshift(mbc1.ram_bank, 5)
    end
    return cartridge.raw_data[(rom_bank * 16 * 1024) + (address - 0x4000)]
  end

  if address >= 0xA000 and address <= 0xBFFF and mbc1.ram_enable then
    local ram_bank = 0
    if mbc1.mode == 1 then
      ram_bank = mbc1.ram_bank
    end
    return external_ram[(address - 0xA000) + (ram_bank * 8 * 1024)]
  end

  return 0x00
end
mbc1.mt.__newindex = function(table, address, value)
  if address <= 0x1FFF then
    if bit32.band(0x0A, value) == 0x0A then
      mbc1.ram_enable = true
    else
      mbc1.ram_enable = false
    end
    return
  end
  if address >= 0x2000 and address <= 0x3FFF then
    -- Select the lower 5 bits of the ROM bank
    -- HARDWARE BUG: bank 0 is translated into bank 1 for weird reasons
    if value == 0 then
      value = 1
    end
    mbc1.rom_bank = bit32.band(value, 0x1F)
    return
  end
  if address >= 0x4000 and address <= 0x5FFF then
    mbc1.ram_bank = bit32.band(value, 0x03)
    return
  end
  if address >= 0x6000 and address <= 0x7FFF then
    mbc1.mode = bit32.band(value, 0x01)
    return
  end

  -- Handle actually writing to External RAM
  if address >= 0xA000 and address <= 0xBFFF and mbc1.ram_enable then
    local ram_bank = 0
    if mbc1.mode == 1 then
      ram_bank = mbc1.ram_bank
    end
    external_ram[(address - 0xA000) + (ram_bank * 16 * 1024)] = value
    return
  end
end
setmetatable(mbc1, mbc1.mt)

local mbc_mappings = {}
mbc_mappings[0x00] = mbc_none
mbc_mappings[0x01] = mbc1
mbc_mappings[0x02] = mbc1
mbc_mappings[0x03] = mbc1

cartridge.load = function(file_data, size)
  print("Reading cartridge into memory...")
  cartridge.raw_data = {}
  for i = 0, size - 1 do
    cartridge.raw_data[i] = file_data:byte(i + 1)
  end
  print("Read " .. math.ceil(#cartridge.raw_data / 1024) .. " kB")
  cartridge.header = rom_header.parse_cartridge_header(cartridge.raw_data)
  rom_header.print_cartridge_header(cartridge.header)

  -- TODO: Not this please.
  -- print("Copying cart data into lower 0x7FFF of main memory...")
  -- for i = 0, 0x7FFF do
  --  memory[i] = cartridge.raw_data[i]
  --end
  if mbc_mappings[cartridge.header.mbc_type] then
    print("Using mapper: ", cartridge.header.mbc_name)
    memory.map_block(0x0000, 0x7FFF, mbc_mappings[cartridge.header.mbc_type])
  else
    print("Unsupported MBC type! Defaulting to ROM ONLY, game will probably not boot.")
    memory.map_block(0x0000, 0x7FFF, mbc_mappings[0x00])
  end

end

return cartridge
