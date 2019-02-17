local bit32 = require("bit")

local Registers = {}

function Registers.new(audio, modules, cache)
  local io = modules.io
  local ports = io.ports

  local registers = {}

    -- Audio status register
  io.read_logic[0x26] = function()
    return 0
  end

  function square_period(high_byte, low_byte)
    local frequency_high_bits = bit32.band(high_byte, 0x07)
    local frequency_low_bits = low_byte
    local frequency = bit32.lshift(frequency_high_bits, 8) + frequency_low_bits
    return (2048 - frequency) * 4
  end

  -- Channel 1 Frequency Sweep
  io.write_logic[ports.NR10] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR10] = byte
  end

  -- Channel 1 Sound Length / Wave Pattern Duty
  io.write_logic[ports.NR11] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR11] = byte
  end

  -- Channel 1 Volume Envelope
  io.write_logic[ports.NR12] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR12] = byte
  end

  -- Channel 1 Frequency - Low Bits
  io.write_logic[ports.NR13] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR13] = byte
    local period = square_period(io.ram[ports.NR14], io.ram[ports.NR13])
    audio.tone1.generator.timer:setPeriod(period)
  end

  -- Channel 1 Frequency and Trigger - High Bits
  io.write_logic[ports.NR14] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR14] = byte
    local trigger = bit32.band(byte, 0x80) ~= 0
    local length_enable = bit32.band(byte, 0x40) ~= 0
    local period = square_period(io.ram[ports.NR14], io.ram[ports.NR13])
    audio.tone1.generator.timer:setPeriod(period)
  end

  -- Channel 2 Sound Length / Wave Pattern Duty
  io.write_logic[ports.NR21] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR21] = byte
  end

  -- Channel 2 Volume Envelope
  io.write_logic[ports.NR22] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR22] = byte
  end

  -- Channel 2 Frequency - Low Bits
  io.write_logic[ports.NR23] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR23] = byte
    local period = square_period(io.ram[ports.NR24], io.ram[ports.NR23])
    audio.tone2.generator.timer:setPeriod(period)
  end

  -- Channel 2 Frequency and Trigger - High Bits
  io.write_logic[ports.NR24] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR24] = byte
    local trigger = bit32.band(byte, 0x80) ~= 0
    local length_enable = bit32.band(byte, 0x40) ~= 0
    local period = square_period(io.ram[ports.NR24], io.ram[ports.NR23])
    audio.tone2.generator.timer:setPeriod(period)
  end

  -- Channel 3 Enabled
  io.write_logic[ports.NR30] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR30] = byte
  end

  -- Channel 3 Length
  io.write_logic[ports.NR31] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR31] = byte
  end

  -- Channel 3 Volume
  io.write_logic[ports.NR32] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR32] = byte
  end

  -- Channel 3 Frequency - Low Bits
  io.write_logic[ports.NR33] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR33] = byte
  end

  -- Channel 3 Frequency and Trigger - High Bits
  io.write_logic[ports.NR34] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR34] = byte
  end

  -- Channel 4 Length
  io.write_logic[ports.NR41] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR41] = byte
  end

  -- Channel 4 Volume Envelope
  io.write_logic[ports.NR42] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR42] = byte
  end

  -- Channel 4 Polynomial Counter
  io.write_logic[ports.NR43] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR43] = byte
  end

  -- Channel 4 Trigger
  io.write_logic[ports.NR44] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR44] = byte
  end

  return registers
end

return Registers