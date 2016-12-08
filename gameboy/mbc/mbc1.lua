local mbc1 = {}
mbc1.raw_data = {}
mbc1.external_ram = {}
mbc1.rom_bank = 1
mbc1.ram_bank = 0
mbc1.mode = 0 --0 = ROM bank mode, 1 = RAM bank mode
mbc1.ram_enable = false
mbc1.mt = {}
mbc1.mt.__index = function(table, address)
  -- Lower 16k: return the first bank, always
  if address <= 0x3FFF then
    return mbc1.raw_data[address]
  end
  -- Upper 16k: return the currently selected bank
  if address >= 0x4000 and address <= 0x7FFF then
    local rom_bank = mbc1.rom_bank
    if mbc1.mode == 0 then
      rom_bank = rom_bank + bit32.lshift(mbc1.ram_bank, 5)
    end
    return mbc1.raw_data[(rom_bank * 16 * 1024) + (address - 0x4000)]
  end

  if address >= 0xA000 and address <= 0xBFFF and mbc1.ram_enable then
    local ram_bank = 0
    if mbc1.mode == 1 then
      ram_bank = mbc1.ram_bank
    end
    return mbc1.external_ram[(address - 0xA000) + (ram_bank * 8 * 1024)]
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
    value = bit32.band(value, 0x1F)
    if value == 0 then
      value = 1
    end
    mbc1.rom_bank = value
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
    mbc1.external_ram[(address - 0xA000) + (ram_bank * 8 * 1024)] = value
    return
  end
end
setmetatable(mbc1, mbc1.mt)

return mbc1
