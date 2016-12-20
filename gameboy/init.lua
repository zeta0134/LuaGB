local gameboy = {}

gameboy.cartridge = require("gameboy/cartridge")
gameboy.graphics = require("gameboy/graphics")
gameboy.input = require("gameboy/input")
gameboy.interrupts = require("gameboy/interrupts")
gameboy.io = require("gameboy/io")
gameboy.memory = require("gameboy/memory")
gameboy.timers = require("gameboy/timers")
gameboy.z80 = require("gameboy/z80")

gameboy.initialize = function()
  gameboy.graphics.initialize()

  gameboy.reset()
end

gameboy.reset = function()
  -- Resets the gameboy's internal state to just after the power-on and boot sequence
  -- (Does NOT unload the cartridge)

  -- Note: IO needs to come first here, as some subsequent modules
  -- manipulate IO registers during reset / initialization
  gameboy.io.reset()
  gameboy.memory.reset()
  gameboy.cartridge.reset()
  gameboy.graphics.reset() -- Note to self: this needs to come AFTER resetting IO
  gameboy.timers.reset()
  gameboy.z80.reset()

  gameboy.interrupts.enabled = 1

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
