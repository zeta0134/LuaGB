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

return cartridge
