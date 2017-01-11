local bit32 = require("bit")

local mbc5 = {}
mbc5.raw_data = {}
mbc5.external_ram = {}
mbc5.rom_bank = 0
mbc5.ram_bank = 0
mbc5.ram_enable = false
mbc5.mt = {}
mbc5.mt.__index = function(table, address)
  -- Lower 16k: return the first bank, always
  if address <= 0x3FFF then
    return mbc5.raw_data[address]
  end
  -- Upper 16k: return the currently selected bank
  if address >= 0x4000 and address <= 0x7FFF then
    local rom_bank = mbc5.rom_bank
    return mbc5.raw_data[(rom_bank * 16 * 1024) + (address - 0x4000)]
  end

  if address >= 0xA000 and address <= 0xBFFF and mbc5.ram_enable then
    local ram_bank = mbc5.ram_bank
    return mbc5.external_ram[(address - 0xA000) + (ram_bank * 8 * 1024)]
  end
  return 0x00
end
mbc5.mt.__newindex = function(table, address, value)
  if address <= 0x1FFF then
    if bit32.band(0x0A, value) == 0x0A then
      mbc5.ram_enable = true
    else
      mbc5.ram_enable = false
    end
    return
  end
  if address >= 0x2000 and address <= 0x2FFF then
    -- Write the lower 8 bits of the ROM bank
    mbc5.rom_bank = bit32.band(mbc5.rom_bank, 0xFF00) + value
    return
  end
  if address >= 0x3000 and address <= 0x3FFF then
    -- Write the upper 1 bits of the ROM bank
    mbc5.rom_bank = bit32.band(mbc5.rom_bank, 0xFF) + bit32.lshift(bit32.band(value, 0x01), 8)
    return
  end
  if address >= 0x4000 and address <= 0x5FFF then
    if value <= 0x0F then
      mbc5.ram_bank = value
      return
    end
  end

  -- Handle actually writing to External RAM
  if address >= 0xA000 and address <= 0xBFFF and mbc5.ram_enable then
    local ram_bank = mbc5.ram_bank
    mbc5.external_ram[(address - 0xA000) + (ram_bank * 8 * 1024)] = value
    mbc5.external_ram.dirty = true
    return
  end
end

mbc5.reset = function(self)
  self.rom_bank = 1
  self.ram_bank = 0
  self.ram_enable = false
end

mbc5.save_state = function(self)
  return {
    rom_bank = self.rom_bank,
    ram_bank = self.ram_bank,
    ram_enable = self.ram_enable}
end

mbc5.load_state = function(self, state_data)
  self:reset()

  self.rom_bank = state_data.rom_bank
  self.ram_bank = state_data.ram_bank
  self.ram_enable = state_data.ram_enable
end

setmetatable(mbc5, mbc5.mt)

return mbc5
