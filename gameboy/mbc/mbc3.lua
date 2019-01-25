local bit32 = require("bit")

local Mbc3 = {}

function Mbc3.new()
  local mbc3 = {}
  mbc3.raw_data = {}
  mbc3.external_ram = {}
  mbc3.header = {}
  mbc3.rom_bank = 0
  mbc3.ram_bank = 0
  mbc3.ram_enable = false
  mbc3.rtc_enable = false
  mbc3.rtc_select = 0x08
  mbc3.rtc = {}
  mbc3.rtc[0x08] = 0
  mbc3.rtc[0x09] = 0
  mbc3.rtc[0x0A] = 0
  mbc3.rtc[0x0B] = 0
  mbc3.rtc[0x0C] = 0
  mbc3.mt = {}
  mbc3.mt.__index = function(table, address)
    -- Lower 16k: return the first bank, always
    if address <= 0x3FFF then
      return mbc3.raw_data[address]
    end
    -- Upper 16k: return the currently selected bank
    if address >= 0x4000 and address <= 0x7FFF then
      local rom_bank = mbc3.rom_bank
      return mbc3.raw_data[(rom_bank * 16 * 1024) + (address - 0x4000)]
    end

    if address >= 0xA000 and address <= 0xBFFF and mbc3.ram_enable then
      if mbc3.rtc_enable then
        return mbc3.rtc[mbc3.rtc_select]
      else
        local ram_bank = mbc3.ram_bank
        return mbc3.external_ram[(address - 0xA000) + (ram_bank * 8 * 1024)]
      end
    end
    return 0x00
  end
  mbc3.mt.__newindex = function(table, address, value)
    if address <= 0x1FFF then
      if bit32.band(0x0A, value) == 0x0A then
        mbc3.ram_enable = true
      else
        mbc3.ram_enable = false
      end
      return
    end
    if address >= 0x2000 and address <= 0x3FFF then
      -- Select the lower 7 bits of the ROM bank
      value = bit32.band(value, 0x7F)
      if value == 0 then
        value = 1
      end
      mbc3.rom_bank = value
      return
    end
    if address >= 0x4000 and address <= 0x5FFF then
      mbc3.rtc_enable = false
      if value <= 0x03 then
        mbc3.ram_bank = bit32.band(value, 0x03)
        return
      end
      if value >= 0x08 and value <= 0x0C then
        mbc3.rtc_enable = true
        mbc3.rtc_select = value
        return
      end
    end
    if address >= 0x6000 and address <= 0x7FFF then
      -- Would "latch" the RTC registers, not implemented
      return
    end

    -- Handle actually writing to External RAM
    if address >= 0xA000 and address <= 0xBFFF and mbc3.ram_enable then
      local ram_bank = mbc3.ram_bank
      mbc3.external_ram[(address - 0xA000) + (ram_bank * 8 * 1024)] = value
      mbc3.external_ram.dirty = true
      return
    end
  end

  mbc3.reset = function(self)
    self.rom_bank = 1
    self.ram_bank = 0
    self.ram_enable = false
    self.rtc_enable = false
    self.rtc_select = 0x08
  end

  mbc3.save_state = function(self)
    return {
      rom_bank = self.rom_bank,
      ram_bank = self.ram_bank,
      ram_enable = self.ram_enable,
      rtc_enable = self.rtc_enable,
      rtc_select = self.rtc_enable}
  end

  mbc3.load_state = function(self, state_data)
    self:reset()

    self.rom_bank = state_data.rom_bank
    self.ram_bank = state_data.ram_bank
    self.ram_enable = state_data.ram_enable
    self.rtc_enable = state_data.rtc_enable
    self.rtc_select = state_data.rtc_select
  end

  setmetatable(mbc3, mbc3.mt)

  return mbc3
end

return Mbc3
