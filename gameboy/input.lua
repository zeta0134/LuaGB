local bit32 = require("bit")

local memory = require("gameboy/memory")
local io = require("gameboy/io")

local input = {}

input.keys = {}
input.keys.Left = 0
input.keys.Right = 0
input.keys.Up = 0
input.keys.Down = 0
input.keys.A = 0
input.keys.B = 0
input.keys.Start = 0
input.keys.Select = 0

input.update = function()
  local d_pad_bits = input.keys.Right +
               bit32.lshift(input.keys.Left, 1) +
               bit32.lshift(input.keys.Up, 2) +
               bit32.lshift(input.keys.Down, 3)
  local button_bits = input.keys.A +
                bit32.lshift(input.keys.B, 1) +
                bit32.lshift(input.keys.Select, 2) +
                bit32.lshift(input.keys.Start, 3)

  local active_bits = 0
  if bit32.band(io.ram[io.ports.JOYP], 0x20) == 0 then
    active_bits = bit32.bor(active_bits, button_bits)
  end
  if bit32.band(io.ram[io.ports.JOYP], 0x10) == 0 then
    active_bits = bit32.bor(active_bits, d_pad_bits)
  end
  active_bits = bit32.bnot(active_bits)

  io.ram[io.ports.JOYP] = bit32.bor(bit32.band(io.ram[io.ports.JOYP], 0xF0), bit32.band(active_bits, 0x0F))
end

local decode_snes_command = function(command_bits)
  local command_bytes = {}
  for i = 0, 15 do
    command_bytes[i] = 0
    for b = 0, 7 do
      command_bytes[i] = bit32.lshift(command_bytes[i], 1)
      command_bytes[i] = command_bytes[i] + command_bits[8 * i + b]
    end
  end

  local command = command_bytes[0]
  local parameters = {}
  for i = 1, 15 do
    parameters[i] = command_bytes[i]
  end
  return command, parameters
end

local last_write = 0
local command_bits = {}
local command_started = false
local command_index = 0

-- Register hooks for input-related registers
io.write_logic[io.ports.JOYP] = function(byte)
  io.ram[io.ports.JOYP] = bit32.band(byte, 0x30)
  input.update()

  local pulse = bit32.rshift(bit32.band(byte, 0x30), 4)
  if command_started then
    if (pulse == 0x1 or pulse == 0x2) and last_write == 0x3 then
      if pulse == 0x2 then
        command_bits[command_index] = 0
      end
      if pulse == 0x1 then
        command_bits[command_index] = 1
      end
      command_index = command_index + 1
      if command_index > 128 then
        if command_bits[128] == 0 then
          print("Valid SNES command, decoding!")
          command, parameters = decode_snes_command(command_bits)
          print("SNES Command: ", command)
          print("SNES Parameters: ", unpack(parameters))
        else
          print("Invalid command! 129th bit was not 0")
          print("Decoding anyway!")
          command, parameters = decode_snes_command(command_bits)
          print("SNES Command: ", command)
          print("SNES Parameters: ", unpack(parameters))
        end
        command_started = false
      end
    end
  else
    -- Check to see if we are starting a new command
    if pulse == 0x3 and last_write == 0x0 then
      command_started = true
      command_index = 0
    end
  end

  last_write = pulse
end

return input
