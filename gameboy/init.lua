local bit32 = require("bit")

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
  gameboy.graphics.initialize(gameboy)

  gameboy.reset()
end

gameboy.types = {}
gameboy.types.dmg = 0
gameboy.types.sgb = 1
gameboy.types.color = 2

gameboy.type = gameboy.types.color

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
  gameboy.z80.reset(gameboy)

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
  while old_scanline == gameboy.io.ram[gameboy.io.ports.LY] and instructions < 100000 do
    gameboy.step()
    instructions = instructions + 1
  end
  gameboy.audio.update()
end

local call_opcodes = {[0xCD]=true, [0xC4]=true, [0xD4]=true, [0xCC]=true, [0xDC]=true}
local rst_opcodes = {[0xC7]=true, [0xCF]=true, [0xD7]=true, [0xDF]=true, [0xE7]=true, [0xEF]=true, [0xF7]=true, [0xFF]=true}
gameboy.step_over = function()
  -- Make sure the *current* opcode is a CALL / RST
  local instructions = 0
  local pc = gameboy.z80.registers.pc
  local opcode = gameboy.memory[pc]
  if call_opcodes[opcode] then
    local return_address = bit32.band(pc + 3, 0xFFFF)
    while gameboy.z80.registers.pc ~= return_address and instructions < 10000000 do
      gameboy.step()
      instructions = instructions + 1
    end
    return
  end
  if rst_opcodes[opcode] then
    local return_address = bit32.band(pc + 1, 0xFFFF)
    while gameboy.z80.registers.pc ~= return_address and instructions < 10000000 do
      gameboy.step()
      instructions = instructions + 1
    end
    return
  end
  print("Not a CALL / RST opcode! Bailing.")
end

local ret_opcodes = {[0xC9]=true, [0xC0]=true, [0xD0]=true, [0xC8]=true, [0xD8]=true, [0xD9]=true}
gameboy.run_until_ret = function()
  local instructions = 0
  while ret_opcodes[gameboy.memory[gameboy.z80.registers.pc]] ~= true and instructions < 10000000 do
    gameboy.step()
    instructions = instructions + 1
  end
end

return gameboy
