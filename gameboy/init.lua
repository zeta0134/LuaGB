local bit32 = require("bit")

local Gameboy = {}

Gameboy.audio = require("gameboy/audio")
Gameboy.cartridge = require("gameboy/cartridge")
Gameboy.dma = require("gameboy/dma")
Gameboy.graphics = require("gameboy/graphics")
Gameboy.input = require("gameboy/input")
Gameboy.interrupts = require("gameboy/interrupts")
Gameboy.io = require("gameboy/io")
Gameboy.memory = require("gameboy/memory")
Gameboy.timers = require("gameboy/timers")
Gameboy.processor = require("gameboy/z80")

function Gameboy:initialize()
  self.audio.initialize()
  self.graphics.initialize(self)
  self.cartridge.initialize(self)

  self:reset()
end

Gameboy.types = {}
Gameboy.types.dmg = 0
Gameboy.types.sgb = 1
Gameboy.types.color = 2

Gameboy.type = Gameboy.types.color

function Gameboy:reset()
  -- Resets the gameboy's internal state to just after the power-on and boot sequence
  -- (Does NOT unload the cartridge)

  -- Note: IO needs to come first here, as some subsequent modules
  -- manipulate IO registers during reset / initialization
  self.audio.reset()
  self.io.reset(self)
  self.memory.reset()
  self.cartridge.reset()
  self.graphics.reset() -- Note to self: this needs to come AFTER resetting IO
  self.timers:reset()
  self.processor.reset(self)

  self.interrupts.enabled = 1
end

function Gameboy:save_state()
  local state = {}
  state.audio = self.audio.save_state()
  state.cartridge = self.cartridge.save_state()
  state.io = self.io.save_state()
  state.memory = self.memory.save_state()
  state.graphics = self.graphics.save_state()
  state.timers = self.timers:save_state()
  state.processor = self.processor.save_state()

  -- Note: the underscore
  state.interrupts_enabled = self.interrupts.enabled
  return state
end

function Gameboy:load_state(state)
  self.audio.load_state(state.audio)
  self.cartridge.load_state(state.cartridge)
  self.io.load_state(state.io)
  self.memory.load_state(state.memory)
  self.graphics.load_state(state.graphics)
  self.timers:load_state(state.timers)
  self.processor.load_state(state.processor)

  -- Note: the underscore
  self.interrupts.enabled = state.interrupts_enabled
end

function Gameboy:step()
  self.timers:update()
  if self.timers.system_clock > self.graphics.next_edge then
    self.graphics.update()
  end
  self.processor.process_instruction()
  return
end

function Gameboy:run_until_vblank()
  local instructions = 0
  while self.io.ram[self.io.ports.LY] == 144 and instructions < 100000 do
    self:step()
    instructions = instructions + 1
  end
  while self.io.ram[self.io.ports.LY] ~= 144 and instructions < 100000  do
    self:step()
    instructions = instructions + 1
  end
  self.audio.update()
end

function Gameboy:run_until_hblank()
  local old_scanline = self.io.ram[self.io.ports.LY]
  local instructions = 0
  while old_scanline == self.io.ram[self.io.ports.LY] and instructions < 100000 do
    self:step()
    instructions = instructions + 1
  end
  self.audio.update()
end

local call_opcodes = {[0xCD]=true, [0xC4]=true, [0xD4]=true, [0xCC]=true, [0xDC]=true}
local rst_opcodes = {[0xC7]=true, [0xCF]=true, [0xD7]=true, [0xDF]=true, [0xE7]=true, [0xEF]=true, [0xF7]=true, [0xFF]=true}

function Gameboy:step_over()
  -- Make sure the *current* opcode is a CALL / RST
  local instructions = 0
  local pc = self.processor.registers.pc
  local opcode = self.memory[pc]
  if call_opcodes[opcode] then
    local return_address = bit32.band(pc + 3, 0xFFFF)
    while self.processor.registers.pc ~= return_address and instructions < 10000000 do
      self:step()
      instructions = instructions + 1
    end
    return
  end
  if rst_opcodes[opcode] then
    local return_address = bit32.band(pc + 1, 0xFFFF)
    while self.processor.registers.pc ~= return_address and instructions < 10000000 do
      self:step()
      instructions = instructions + 1
    end
    return
  end
  print("Not a CALL / RST opcode! Bailing.")
end

local ret_opcodes = {[0xC9]=true, [0xC0]=true, [0xD0]=true, [0xC8]=true, [0xD8]=true, [0xD9]=true}

function Gameboy:run_until_ret()
  local instructions = 0
  while ret_opcodes[self.memory[self.processor.registers.pc]] ~= true and instructions < 10000000 do
    self:step()
    instructions = instructions + 1
  end
end

local gameboy_defaults = {}
for k, v in pairs(Gameboy) do
  gameboy_defaults[k] = v
end

Gameboy.new = function(overrides)
  local new_gameboy = {}
  for k, v in pairs(gameboy_defaults) do
    if overrides[k] then
      new_gameboy[k] = overrides[k]
    else
      new_gameboy[k] = gameboy_defaults[k]
    end
  end

  new_gameboy.memory = new_gameboy.memory.new(new_gameboy)

  new_gameboy.io = new_gameboy.io.new(new_gameboy)

  new_gameboy.interrupts = new_gameboy.interrupts.new(new_gameboy)

  new_gameboy.timers = new_gameboy.timers.new(new_gameboy)

  new_gameboy.audio = new_gameboy.audio.new(new_gameboy)
  new_gameboy.cartridge = new_gameboy.cartridge.new(new_gameboy)
  new_gameboy.dma = new_gameboy.dma.new(new_gameboy)
  new_gameboy.graphics = new_gameboy.graphics.new(new_gameboy)
  new_gameboy.input = new_gameboy.input.new(new_gameboy)
  new_gameboy.processor = new_gameboy.processor.new(new_gameboy)

  new_gameboy:initialize()

  return new_gameboy
end

return Gameboy
