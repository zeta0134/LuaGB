local gameboy = {}

gameboy.audio = require("gameboy/audio")
gameboy.cartridge = require("gameboy/cartridge")
gameboy.graphics = require("gameboy/graphics")
gameboy.input = require("gameboy/input")
gameboy.interrupts = require("gameboy/interrupts")
gameboy.io = require("gameboy/io")
gameboy.memory = require("gameboy/memory")
gameboy.timers = require("gameboy/timers")
gameboy.z80 = require("gameboy/z80")

gameboy.initialize = function()
  gameboy.audio.initialize()
  gameboy.graphics.initialize()

  gameboy.reset()
end

gameboy.reset = function()
  -- Resets the gameboy's internal state to just after the power-on and boot sequence
  -- (Does NOT unload the cartridge)

  -- Note: IO needs to come first here, as some subsequent modules
  -- manipulate IO registers during reset / initialization
  gameboy.audio.reset()
  gameboy.io.reset()
  gameboy.memory.reset()
  gameboy.cartridge.reset()
  gameboy.graphics.reset() -- Note to self: this needs to come AFTER resetting IO
  gameboy.timers.reset()
  gameboy.z80.reset()

  gameboy.interrupts.enabled = 1
end

gameboy.save_state = function()
  local state = {}
  state.audio = gameboy.audio.save_state()
  state.io = gameboy.io.save_state()
  state.memory = gameboy.memory.save_state()
  state.cartridge = gameboy.cartridge.save_state()
  state.graphics = gameboy.graphics.save_state()
  state.timers = gameboy.timers.save_state()
  state.z80 = gameboy.z80.save_state()

  -- Note: the underscore
  state.interrupts_enabled = gameboy.interrupts.enabled
  return state
end

gameboy.load_state = function(state)
  gameboy.audio.load_state(state.audio)
  gameboy.io.load_state(state.io)
  gameboy.memory.load_state(state.memory)
  gameboy.cartridge.load_state(state.cartridge)
  gameboy.graphics.load_state(state.graphics)
  gameboy.timers.load_state(state.timers)
  gameboy.z80.load_state(state.z80)

  -- Note: the underscore
  gameboy.interrupts.enabled = state.interrupts_enabled
end

gameboy.step = function()
  gameboy.timers.update()
  gameboy.graphics.update()
  gameboy.z80.process_instruction()
  return
end

gameboy.run_until_vblank = function()
  local instructions = 0
  while gameboy.io.ram[gameboy.io.ports.LY] == 144 and instructions < 100000 do
    gameboy.step()
    instructions = instructions + 1
  end
  while gameboy.io.ram[gameboy.io.ports.LY] ~= 144 and instructions < 100000  do
    gameboy.step()
    instructions = instructions + 1
  end
  gameboy.audio.update()
end

gameboy.run_until_hblank = function()
  local old_scanline = gameboy.io.ram[gameboy.io.ports.LY]
  local instructions = 0
  while old_scanline == gameboy.io.ram[gameboy.io.ports.LY] and instructions < 100000  do
    gameboy.step()
    instructions = instructions + 1
  end
  gameboy.audio.update()
end

return gameboy
