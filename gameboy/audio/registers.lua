local bit32 = require("bit")

local Registers = {}

function Registers.new(audio, modules, cache)
  local io = modules.io
  local memory = modules.memory
  local ports = io.ports

  local registers = {}

  io.read_mask[ports.NR10] = 0x80
  io.read_mask[ports.NR11] = 0x3F
  io.read_mask[ports.NR12] = 0x00
  io.read_mask[ports.NR13] = 0xFF
  io.read_mask[ports.NR14] = 0xBF

  io.read_mask[0x15] = 0xFF
  io.read_mask[ports.NR21] = 0x3F
  io.read_mask[ports.NR22] = 0x00
  io.read_mask[ports.NR23] = 0xFF
  io.read_mask[ports.NR24] = 0xBF

  io.read_mask[ports.NR30] = 0x7F
  io.read_mask[ports.NR31] = 0xFF
  io.read_mask[ports.NR32] = 0x9F
  io.read_mask[ports.NR33] = 0xFF
  io.read_mask[ports.NR34] = 0xBF

  io.read_mask[0x1F] = 0xFF
  io.read_mask[ports.NR41] = 0xFF
  io.read_mask[ports.NR42] = 0x00
  io.read_mask[ports.NR43] = 0x00
  io.read_mask[ports.NR44] = 0xBF

  io.read_mask[ports.NR50] = 0x00
  io.read_mask[ports.NR51] = 0x00

  for i = 0x27, 0x2F do
    io.read_mask[i] = 0xFF
  end

  io.write_logic[ports.NR50] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR50] = byte
      audio.master_volume_left = bit32.rshift(bit32.band(byte, 0x70), 4)
      audio.master_volume_right = bit32.band(byte, 0x07)
    end
  end

  io.write_logic[ports.NR51] = function(byte)
    if audio.master_enable then
      io.ram[ports.NR51] = byte
      audio.tone1.master_enable_right  = bit32.band(byte, 0x01) ~= 0;
      audio.tone2.master_enable_right  = bit32.band(byte, 0x02) ~= 0;
      audio.wave3.master_enable_right  = bit32.band(byte, 0x04) ~= 0;
      audio.noise4.master_enable_right = bit32.band(byte, 0x08) ~= 0;
      audio.tone1.master_enable_left   = bit32.band(byte, 0x10) ~= 0;
      audio.tone2.master_enable_left   = bit32.band(byte, 0x20) ~= 0;
      audio.wave3.master_enable_left   = bit32.band(byte, 0x40) ~= 0;
      audio.noise4.master_enable_left  = bit32.band(byte, 0x80) ~= 0;
    end
  end

    -- Audio power / status register
  io.read_logic[ports.NR52] = function()
    audio.generate_pending_samples()
    local status = 0
    if audio.tone1:enabled() then
      status = status + 0x01
    end
    if audio.tone2:enabled() then
      status = status + 0x02
    end
    if audio.wave3:enabled() then
      status = status + 0x04
    end
    if audio.noise4:enabled() then
      status = status + 0x08
    end
    if audio.master_enable then
      status = status + 0x80
    end
    return bit32.bor(status, 0x70)
  end

  io.write_logic[ports.NR52] = function(byte)
    local master_enable = bit32.band(byte, 0x80) ~= 0;
    if master_enable == false then
      -- fully disable the APU; clear out ALL the things
      for i = ports.NR10, ports.NR51 do
        memory.write_byte(0xFF00 + i, 0x00)
      end
    end
    audio.master_enable = master_enable
  end

  function square_period(high_byte, low_byte)
    local frequency_high_bits = bit32.band(high_byte, 0x07)
    local frequency_low_bits = low_byte
    local frequency = bit32.lshift(frequency_high_bits, 8) + frequency_low_bits
    return (2048 - frequency) * 4
  end

  function wave_period(high_byte, low_byte)
    local frequency_high_bits = bit32.band(high_byte, 0x07)
    local frequency_low_bits = low_byte
    local frequency = bit32.lshift(frequency_high_bits, 8) + frequency_low_bits
    return (2048 - frequency) * 2
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
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR10] = byte
      local sweep_period = bit32.rshift(bit32.band(byte, 0x70), 4);
      audio.tone1.generator.sweep_timer.period = sweep_period
      audio.tone1.generator.sweep_negate = bit32.band(byte, 0x08) ~= 0;
      audio.tone1.generator.sweep_shift = bit32.band(byte, 0x07);
    end
  end

  -- Channel 1 Sound Length / Wave Pattern Duty
  io.write_logic[ports.NR11] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR11] = byte
      local duty_index = bit32.rshift(byte, 6);
      audio.tone1.generator.waveform = square_duty[duty_index]
      local length_data = bit32.band(byte, 0x3F);
      audio.tone1.length_counter.counter = 64 - length_data
    end
  end

  -- Channel 1 Volume Envelope
  io.write_logic[ports.NR12] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR12] = byte
      if bit32.band(byte, 0xF8) == 0 then
        audio.tone1.dac_enabled = false
      end
    end
  end

  -- Channel 1 Frequency - Low Bits
  io.write_logic[ports.NR13] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR13] = byte
      local period = square_period(io.ram[ports.NR14], io.ram[ports.NR13])
      audio.tone1.generator.timer.period = period
    end
  end

  -- Channel 1 Frequency and Trigger - High Bits
  io.write_logic[ports.NR14] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR14] = byte
      local trigger = bit32.band(byte, 0x80) ~= 0
      audio.tone1.length_counter.length_enabled = bit32.band(byte, 0x40) ~= 0
      local period = square_period(io.ram[ports.NR14], io.ram[ports.NR13])
      audio.tone1.generator.timer.period = period
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
        audio.tone1.generator.sweep_enabled =
          audio.tone1.generator_sweep_shift ~= 0 or
          audio.tone1.generator.sweep_timer.period ~= 0

        if audio.tone1.generator.sweep_shift ~= 0 then
          audio.tone1.generator:check_overflow()
        end

        if bit32.band(io.ram[ports.NR12], 0xF8) ~= 0 then
          audio.tone1.dac_enabled = true
        end
      end
    end
  end

  -- Channel 2 Sound Length / Wave Pattern Duty
  io.write_logic[ports.NR21] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR21] = byte
      local duty_index = bit32.rshift(byte, 6);
      audio.tone2.generator.waveform = square_duty[duty_index]
      local length_data = bit32.band(byte, 0x3F);
      audio.tone2.length_counter.counter = 64 - length_data
    end
  end

  -- Channel 2 Volume Envelope
  io.write_logic[ports.NR22] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR22] = byte
      if bit32.band(byte, 0xF8) == 0 then
        audio.tone2.dac_enabled = false
      end
    end
  end

  -- Channel 2 Frequency - Low Bits
  io.write_logic[ports.NR23] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR23] = byte
      local period = square_period(io.ram[ports.NR24], io.ram[ports.NR23])
      audio.tone2.generator.timer.period = period
    end
  end

  -- Channel 2 Frequency and Trigger - High Bits
  io.write_logic[ports.NR24] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR24] = byte
      local trigger = bit32.band(byte, 0x80) ~= 0
      audio.tone2.length_counter.length_enabled = bit32.band(byte, 0x40) ~= 0
      local period = square_period(io.ram[ports.NR24], io.ram[ports.NR23])
      audio.tone2.generator.timer.period = period
      if trigger then
        audio.tone2.generator.timer:reload()
        reload_volume(audio.tone2.volume_envelope, io.ram[ports.NR22])
        audio.tone2.length_counter.channel_enabled = true
        if audio.tone2.length_counter.counter == 0 then
          audio.tone2.length_counter.counter = 64
        end
        if bit32.band(io.ram[ports.NR22], 0xF8) ~= 0 then
          audio.tone2.dac_enabled = true
        end
      end
    end
  end

  -- Channel 3 Enabled
  io.write_logic[ports.NR30] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR30] = byte
      if bit32.band(byte, 0x80) == 0 then
        audio.wave3.sampler.channel_enabled = false
      end
    end
  end

  -- Channel 3 Length
  io.write_logic[ports.NR31] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR31] = byte
      local length_data = byte;
      audio.wave3.length_counter.counter = 256 - length_data
    end
  end

  local wave_volume_table = {
    [0]=4,
    [1]=0,
    [2]=1,
    [3]=2
  }

  -- Channel 3 Volume
  io.write_logic[ports.NR32] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR32] = byte
      local volume_code = bit32.rshift(bit32.band(byte, 0x60), 5)
      audio.wave3.sampler.volume_shift = wave_volume_table[volume_code]
    end
  end

  -- Channel 3 Frequency - Low Bits
  io.write_logic[ports.NR33] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR33] = byte
      local period = wave_period(io.ram[ports.NR34], io.ram[ports.NR33])
      audio.wave3.sampler.timer.period = period
    end
  end

  -- Channel 3 Frequency and Trigger - High Bits
  io.write_logic[ports.NR34] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR34] = byte
      local trigger = bit32.band(byte, 0x80) ~= 0
      audio.wave3.length_counter.length_enabled = bit32.band(byte, 0x40) ~= 0
      local period = wave_period(io.ram[ports.NR34], io.ram[ports.NR33])
      audio.wave3.sampler.timer.period = period
      if trigger then
        audio.wave3.sampler.position = 0
        audio.wave3.sampler.timer:reload()
        audio.wave3.length_counter.channel_enabled = true
        if audio.wave3.length_counter.counter == 0 then
          audio.wave3.length_counter.counter = 256
        end
        if bit32.band(io.ram[ports.NR30], 0x80) ~= 0 then
          audio.wave3.sampler.channel_enabled = true
        end
      end
    end
  end

  -- Channel 4 Length
  io.write_logic[ports.NR41] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR41] = byte
      local length_data = bit32.band(byte, 0x3F);
      audio.noise4.length_counter.counter = 64 - length_data
    end
  end

  -- Channel 4 Volume Envelope
  io.write_logic[ports.NR42] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR42] = byte
      if bit32.band(byte, 0xF8) == 0 then
        audio.noise4.dac_enabled = false
      end
    end
  end

  -- Channel 4 Polynomial Counter
  io.write_logic[ports.NR43] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR43] = byte
      local divisor_code = bit32.band(byte, 0x7)
      local shift_amount = bit32.rshift(bit32.band(0xF0, byte), 4)    
      audio.noise4.lfsr.width_mode = bit32.rshift(bit32.band(0x08, byte), 3)
      audio.noise4.lfsr:setPeriod(divisor_code, shift_amount)
    end
  end

  -- Channel 4 Trigger
  io.write_logic[ports.NR44] = function(byte)
    if audio.master_enable then
      audio.generate_pending_samples()
      io.ram[ports.NR44] = byte
      local trigger = bit32.band(byte, 0x80) ~= 0
      audio.noise4.length_counter.length_enabled = bit32.band(byte, 0x40) ~= 0
      if trigger then
        audio.noise4.lfsr.timer:reload()
        reload_volume(audio.noise4.volume_envelope, io.ram[ports.NR42])
        audio.noise4.length_counter.channel_enabled = true
        if audio.noise4.length_counter.counter == 0 then
          audio.noise4.length_counter.counter = 64
        end
        audio.noise4.lfsr:reset()
        if bit32.band(io.ram[ports.NR42], 0xF8) ~= 0 then
          audio.noise4.dac_enabled = true
        end
      end
    end
  end

  return registers
end

return Registers