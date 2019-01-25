local rom_header = require("gameboy/rom_header")

local MbcNone = require("gameboy/mbc/none")
local Mbc1 = require("gameboy/mbc/mbc1")
local Mbc2 = require("gameboy/mbc/mbc2")
local Mbc3 = require("gameboy/mbc/mbc3")
local Mbc5 = require("gameboy/mbc/mbc5")

local Cartridge = {}

function Cartridge.new(modules)
  local cartridge = {}

  local io = modules.io
  local memory = modules.memory
  local ports = io.ports

  local mbc_none = MbcNone.new()
  local mbc1 = Mbc1.new()
  local mbc2 = Mbc2.new()
  local mbc3 = Mbc3.new()
  local mbc5 = Mbc5.new()

  cartridge.external_ram = memory.generate_block(128 * 1024)
  cartridge.external_ram.dirty = false

  local mbc_mappings = {}
  mbc_mappings[0x00] = {mbc=mbc_none, options={}}
  mbc_mappings[0x01] = {mbc=mbc1, options={}}
  mbc_mappings[0x02] = {mbc=mbc1, options={}}
  mbc_mappings[0x03] = {mbc=mbc1, options={}}

  mbc_mappings[0x05] = {mbc=mbc2, options={}}
  mbc_mappings[0x06] = {mbc=mbc2, options={}}

  mbc_mappings[0x0F] = {mbc=mbc3, options={}}
  mbc_mappings[0x10] = {mbc=mbc3, options={}}
  mbc_mappings[0x12] = {mbc=mbc3, options={}}
  mbc_mappings[0x11] = {mbc=mbc3, options={}}
  mbc_mappings[0x13] = {mbc=mbc3, options={}}

  mbc_mappings[0x19] = {mbc=mbc5, options={}}
  mbc_mappings[0x1A] = {mbc=mbc5, options={}}
  mbc_mappings[0x1B] = {mbc=mbc5, options={}}
  mbc_mappings[0x1C] = {mbc=mbc5, options={rumble_pak=true}}
  mbc_mappings[0x1D] = {mbc=mbc5, options={rumble_pak=true}}
  mbc_mappings[0x1E] = {mbc=mbc5, options={rumble_pak=true}}

  cartridge.initialize = function(gameboy)
    cartridge.gameboy = gameboy
  end

  cartridge.load = function(file_data, size)
    print("Reading cartridge into memory...")
    cartridge.raw_data = {}
    for i = 0, size - 1 do
      cartridge.raw_data[i] = file_data:byte(i + 1)
    end
    print("Read " .. math.ceil(#cartridge.raw_data / 1024) .. " kB")
    cartridge.header = rom_header.parse_cartridge_header(cartridge.raw_data)
    rom_header.print_cartridge_header(cartridge.header)

    if mbc_mappings[cartridge.header.mbc_type] then
      local MBC = mbc_mappings[cartridge.header.mbc_type].mbc
      for k, v in pairs(mbc_mappings[cartridge.header.mbc_type].options) do
        MBC[k] = v
      end
      print("Using mapper: ", cartridge.header.mbc_name)
      MBC.raw_data = cartridge.raw_data
      MBC.external_ram = cartridge.external_ram
      MBC.header = cartridge.header
      -- Cart ROM
      memory.map_block(0x00, 0x7F, MBC)
      -- External RAM
      memory.map_block(0xA0, 0xBF, MBC, 0x0000)
    else
      local MBC = mbc_mappings[0x00].mbc
      print("Unsupported MBC type! Defaulting to ROM ONLY, game will probably not boot.")
      MBC.raw_data = cartridge.raw_data
      MBC.external_ram = cartridge.external_ram
      memory.map_block(0x00, 0x7F, MBC)
      memory.map_block(0xA0, 0xBF, MBC, 0x0000)
    end

    -- select a gameboy type based on the cart header
    if cartridge.header.color then
      cartridge.gameboy.type = cartridge.gameboy.types.color
    else
      cartridge.gameboy.type = cartridge.gameboy.types.dmg
    end

    -- Add a guard to cartridge.raw_data, such that any out-of-bounds reads return 0x00
    cartridge.raw_data.mt = {}
    cartridge.raw_data.mt.__index = function(table, address)
      -- Data doesn't exist? Tough luck; return 0x00
      return 0x00
    end

    setmetatable(cartridge.raw_data, cartridge.raw_data.mt)
  end

  cartridge.reset = function()
    if cartridge.header then
      -- Simulates a power cycle, resetting selected banks and other variables
      if mbc_mappings[cartridge.header.mbc_type] then
        mbc_mappings[cartridge.header.mbc_type].mbc:reset()
      else
        -- Calling this for logical completeness, but
        -- mbc_mappings[0x00] is actually type none,
        -- whose reset function is a no-op
        mbc_mappings[0x00].mbc:reset()
      end
    end

    -- TODO: Figure out if we care enough to reset
    -- External RAM here, for games which don't have
    -- a BATTERY in their cartridge type
  end

  cartridge.save_state = function()
    -- Note: for NOW, don't worry about the cartridge
    -- header, and assume a cart swap has not happened
    if mbc_mappings[cartridge.header.mbc_type] then
      return mbc_mappings[cartridge.header.mbc_type].mbc:save_state()
    else
      mbc_mappings[0x00].mbc:save_state()
    end
  end

  cartridge.load_state = function(state_data)
    -- Note: for NOW, don't worry about the cartridge
    -- header, and assume a cart swap has not happened
    if mbc_mappings[cartridge.header.mbc_type] then
      return mbc_mappings[cartridge.header.mbc_type].mbc:load_state(state_data)
    else
      mbc_mappings[0x00].mbc:load_state(state_data)
    end
  end

  return cartridge
end

return Cartridge
