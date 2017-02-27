local bit32 = require("bit")

local Input = {}

function Input.new(modules)
  local memory = modules.memory
  local io = modules.io

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

    io.ram[io.ports.JOYP] = bit32.bor(0xC0, bit32.band(io.ram[io.ports.JOYP], 0x30), bit32.band(active_bits, 0x0F))
  end

  local snes_packet_names = {}
  snes_packet_names[0x00] = "PAL 01"
  snes_packet_names[0x01] = "PAL 23"
  snes_packet_names[0x02] = "PAL 03"
  snes_packet_names[0x03] = "PAL 12"
  snes_packet_names[0x04] = "ATTR_BLK"
  snes_packet_names[0x05] = "ATTR_LIN"
  snes_packet_names[0x06] = "ATTR_DIV"
  snes_packet_names[0x07] = "ATTR_CHR"
  snes_packet_names[0x08] = "SOUND"
  snes_packet_names[0x09] = "SOU_TRN"
  snes_packet_names[0x0A] = "PAL_SET"
  snes_packet_names[0x0B] = "PAL_TRN"
  snes_packet_names[0x0C] = "ATRC_EN"
  snes_packet_names[0x0D] = "TEST_EN"
  snes_packet_names[0x0E] = "ICON_EN"
  snes_packet_names[0x0F] = "DATA_SND"
  snes_packet_names[0x10] = "DATA_TRN"
  snes_packet_names[0x11] = "MLT_REG"
  snes_packet_names[0x12] = "JUMP"
  snes_packet_names[0x13] = "CHR_TRN"
  snes_packet_names[0x14] = "PCT_TRN"
  snes_packet_names[0x15] = "ATTR_TRN"
  snes_packet_names[0x16] = "ATTR_SET"
  snes_packet_names[0x17] = "MASK_EN"
  snes_packet_names[0x18] = "OBJ_TRN"

  local decode_snes_command = function(command_bits)
    local command_bytes = {}
    for i = 0, 15 do
      command_bytes[i] = 0
      for b = 0, 7 do
        command_bytes[i] = command_bytes[i] + bit32.lshift(command_bits[8 * i + b], 8)
        command_bytes[i] = bit32.rshift(command_bytes[i], 1)

      end
    end

    local command = bit32.rshift(bit32.band(command_bytes[0], 0xF8), 3)
    local packet_length = bit32.band(command_bytes[0], 0x7)
    local parameters = {}
    for i = 1, 15 do
      parameters[i] = command_bytes[i]
    end
    return command, packet_length, parameters
  end

  local last_write = 0
  local command_bits = {}
  local command_started = false
  local command_index = 0

  local hex = function(str)
    return string.format("$%02X", str)
  end

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
          if command_bits[128] ~= 0 then
            print("Invalid command! 129th bit was not 0")
          end
          local command, length, parameters = decode_snes_command(command_bits)
          local command_name = snes_packet_names[command] or "UNKNOWN!!"
          print("SNES Command: " .. command_name .. " [" .. hex(command) .. "] Length: " .. length)
          local hex_params = hex(parameters[1])
          for i = 2, 15 do
            hex_params = hex_params .. " " .. hex(parameters[i])
          end
          print("SNES Parameters: ", hex_params)
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
end

return Input
