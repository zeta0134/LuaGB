local gameboy = {}

gameboy.memory = require("gameboy/memory")
require("gameboy/z80")
gameboy.graphics = require("gameboy/graphics")
require("gameboy/rom_header")
gameboy.input = require("gameboy/input")
gameboy.cartridge = require("gameboy/cartridge")

gameboy.initialize = function()
  gameboy.memory.initialize()
  gameboy.graphics.initialize()
end



return gameboy
