local gameboy = {}

gameboy.memory = require("gameboy/memory")
gameboy.z80 = require("gameboy/z80")
gameboy.graphics = require("gameboy/graphics")
gameboy.input = require("gameboy/input")
gameboy.cartridge = require("gameboy/cartridge")
gameboy.timers = require("gameboy/timers")
gameboy.interrupts = require("gameboy/interrupts")

gameboy.initialize = function()
  gameboy.memory.initialize()
  gameboy.graphics.initialize()
end

gameboy.step = function()
  gameboy.graphics.update()
  gameboy.input.update()
  return process_instruction()
end

gameboy.run_until_vblank = function()
  local instructions = 0
  while gameboy.graphics.scanline() == 144 and instructions < 100000 do
    gameboy.step()
    instructions = instructions + 1
  end
  while gameboy.graphics.scanline() ~= 144 and instructions < 100000  do
    gameboy.step()
    instructions = instructions + 1
  end
end

gameboy.run_until_hblank = function()
  local old_scanline = gameboy.graphics.scanline()
  local instructions = 0
  while old_scanline == gameboy.graphics.scanline() and instructions < 100000  do
    gameboy.step()
    instructions = instructions + 1
  end
end

return gameboy
