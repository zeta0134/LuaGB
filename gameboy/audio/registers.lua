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

  function reload_volume(volume_envelope, byte)
    local volume = bit32.rshift(byte, 4)
    local adjustment = bit32.rshift(bit32.band(byte, 0x08), 3)
    if adjustment == 0 then
      adjustment = -1
    end
    local period = bit32.band(byte, 0x07)
    if period == 0 then
      period = 8
    end
    volume_envelope.timer:reload(period)
    volume_envelope:setVolume(volume)
    volume_envelope:setAdjustment(adjustment)
  end

  local square_duty = {
    [0]=0x01, -- 00000001
    [1]=0x81, -- 10000001
    [2]=0x87, -- 10000111
    [3]=0x7E} -- 01111110

  -- Channel 1 Frequency Sweep
  io.write_logic[ports.NR10] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR10] = byte
    local sweep_period = bit32.rshift(bit32.band(byte, 0x70), 4);
    audio.tone1.generator.sweep_timer:setPeriod(sweep_period)
    audio.tone1.generator.sweep_negate = bit32.band(byte, 0x08) ~= 0;
    audio.tone1.generator.sweep_shift = bit32.band(byte, 0x07);
  end

  -- Channel 1 Sound Length / Wave Pattern Duty
  io.write_logic[ports.NR11] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR11] = byte
    local duty_index = bit32.rshift(byte, 6);
    audio.tone1.generator.waveform = square_duty[duty_index]
    local length_data = bit32.band(byte, 0x3F);
    audio.tone1.length_counter.counter = 64 - length_data
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
    audio.tone1.length_counter.length_enabled = bit32.band(byte, 0x40) ~= 0
    local period = square_period(io.ram[ports.NR14], io.ram[ports.NR13])
    audio.tone1.generator.timer:setPeriod(period)
    if trigger then
      audio.tone1.generator.timer:reload()
      reload_volume(audio.tone1.volume_envelope, io.ram[ports.NR12])
      audio.tone1.length_counter.channel_enabled = true
      if audio.tone1.length_counter.counter == 0 then
        audio.tone1.length_counter.counter = 64
      end
      local frequency_shadow = bit32.lshift(bit32.band(io.ram[ports.NR14], 0x07), 8) + io.ram[ports.NR13]
      audio.tone1.generator.frequency_shadow = frequency_shadow
      audio.tone1.generator.sweep_timer:reload()
      audio.tone1.generator.channel_enabled = true
    end
  end

  -- Channel 2 Sound Length / Wave Pattern Duty
  io.write_logic[ports.NR21] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR21] = byte
    local duty_index = bit32.rshift(byte, 6);
    audio.tone2.generator.waveform = square_duty[duty_index]
    local length_data = bit32.band(byte, 0x3F);
    audio.tone2.length_counter.counter = 64 - length_data
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
    audio.tone2.length_counter.length_enabled = bit32.band(byte, 0x40) ~= 0
    local period = square_period(io.ram[ports.NR24], io.ram[ports.NR23])
    audio.tone2.generator.timer:setPeriod(period)
    if trigger then
      audio.tone2.generator.timer:reload()
      reload_volume(audio.tone2.volume_envelope, io.ram[ports.NR22])
      audio.tone2.length_counter.channel_enabled = true
      if audio.tone2.length_counter.counter == 0 then
        audio.tone2.length_counter.counter = 64
      end
    end
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