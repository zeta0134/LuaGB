local bit32 = require("bit")

local io = require("gameboy/io")
local timers = require("gameboy/timers")
local ports = io.ports

local audio = {}

-- Note: for simplicity, we sample at 44100 Hz. Deal. I'll not bother
-- to implement any other sampling frequencies until this is more stable.

audio.buffer = {}

audio.initialize = function()
  for i = 0, 32768 do
    audio.buffer[i] = 0
  end
end

audio.tone1 = {}
audio.tone1.period = 128 -- in cycles
audio.tone1.volume_initial = 0
audio.tone1.volume_direction = 1
audio.tone1.volume_step_length = 0 -- in cycles
audio.tone1.max_length = 0          -- in cycles
audio.tone1.continuous = false
audio.tone1.duty_length = .75       -- percentage, from 0-1
audio.tone1.base_cycle = 0
audio.tone1.frequency_shadow = 0
audio.tone1.frequency_shift_time = 0 -- in cycles, 0 == disabled
audio.tone1.frequency_shift_counter = 0 -- should be reset on trigger
audio.tone1.frequency_shift_direction = 1
audio.tone1.frequency_shift_amount = 0
audio.tone1.disabled = false

audio.tone2 = {}
audio.tone2.period = 128 -- in cycles
audio.tone2.volume_initial = 0
audio.tone2.volume_direction = 1
audio.tone2.volume_step_length = 0 -- in cycles
audio.tone2.max_length = 0          -- in cycles
audio.tone2.continuous = false
audio.tone2.duty_length = .75       -- percentage, from 0-1
audio.tone2.base_cycle = 0

audio.wave3 = {}
audio.wave3.enabled = false
audio.wave3.max_length = 0 -- in cycles
audio.wave3.volume_shift = 0
audio.wave3.period = 0 -- in cycles
audio.wave3.continuous = false
audio.wave3.base_cycle = 0

local wave_patterns = {}
wave_patterns[0] = .125
wave_patterns[1] = .25
wave_patterns[2] = .50
wave_patterns[3] = .75

io.write_logic[ports.NR10] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR10] = byte
  local sweep_time = bit32.rshift(bit32.band(byte, 0x70), 4)
  audio.tone1.frequency_shift_time = sweep_time * 32768
  if bit32.band(byte, 0x08) ~= 0 then
    audio.tone1.frequency_shift_direction = -1
  else
    audio.tone1.frequency_shift_direction = 1
  end
  audio.tone1.frequency_shift_amount = bit32.band(byte, 0x07)
end

-- Channel 1 Sound Length / Wave Pattern Duty
io.write_logic[ports.NR11] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR11] = byte
  local wave_pattern = bit32.rshift(bit32.band(byte, 0xC0), 6)
  audio.tone1.duty_length = wave_patterns[wave_pattern]
  local length_data = bit32.band(byte, 0x3F)
  local length_cycles = (64 - length_data) * 16384
  audio.tone1.max_length = length_cycles
end

-- Channel 1 Volume Envelope
io.write_logic[ports.NR12] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR12] = byte
  audio.tone1.volume_initial = bit32.rshift(bit32.band(byte, 0xF0), 4)
  local direction = bit32.band(byte, 0x08)
  if direction > 0 then
    audio.tone1.volume_direction = 1
  else
    audio.tone1.volume_direction = -1
  end
  local envelope_step_data = bit32.band(byte, 0x07)
  local envelope_step_cycles = envelope_step_data * 65536
  audio.tone1.volume_step_length = envelope_step_cycles
end

-- Channel 1 Frequency - Low Bits
io.write_logic[ports.NR13] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR13] = byte
  local freq_high = bit32.lshift(bit32.band(io.ram[ports.NR14], 0x07), 8)
  local freq_low = byte
  local freq_value = freq_high + freq_low
  audio.tone1.period = 32 * (2048 - freq_value)
end

-- Channel 1 Frequency and Trigger - High Bits
io.write_logic[ports.NR14] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR14] = byte
  local restart = (bit32.band(byte, 0x80) ~= 0)
  local continuous = (bit32.band(byte, 0x40) == 0)
  local freq_high = bit32.lshift(bit32.band(byte, 0x07), 8)
  local freq_low = io.ram[ports.NR13]
  local freq_value = freq_high + freq_low

  audio.tone1.period = 32 * (2048 - freq_value)
  audio.tone1.continuous = continuous
  if restart then
    audio.tone1.base_cycle = timers.system_clock
  end
  audio.tone1.frequency_shadow = freq_value
  audio.tone1.frequency_shift_counter = 0
  audio.tone1.disabled = false
end

-- Channel 2 Sound Length / Wave Pattern Duty
io.write_logic[ports.NR21] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR21] = byte
  local wave_pattern = bit32.rshift(bit32.band(byte, 0xC0), 6)
  audio.tone2.duty_length = wave_patterns[wave_pattern]
  local length_data = bit32.band(byte, 0x3F)
  local length_cycles = (64 - length_data) * 16384
  audio.tone2.max_length = length_cycles
end

-- Channel 2 Volume Envelope
io.write_logic[ports.NR22] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR22] = byte
  audio.tone2.volume_initial = bit32.rshift(bit32.band(byte, 0xF0), 4)
  local direction = bit32.band(byte, 0x08)
  if direction > 0 then
    audio.tone2.volume_direction = 1
  else
    audio.tone2.volume_direction = -1
  end
  local envelope_step_data = bit32.band(byte, 0x07)
  local envelope_step_cycles = envelope_step_data * 65536
  audio.tone2.volume_step_length = envelope_step_cycles
end

-- Channel 2 Frequency - Low Bits
io.write_logic[ports.NR23] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR23] = byte
  local freq_high = bit32.lshift(bit32.band(io.ram[ports.NR24], 0x07), 8)
  local freq_low = byte
  local freq_value = freq_high + freq_low
  audio.tone2.period = 32 * (2048 - freq_value)
end

-- Channel 2 Frequency and Trigger - High Bits
io.write_logic[ports.NR24] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR24] = byte
  local restart = (bit32.band(byte, 0x80) ~= 0)
  local continuous = (bit32.band(byte, 0x40) == 0)
  local freq_high = bit32.lshift(bit32.band(byte, 0x07), 8)
  local freq_low = io.ram[ports.NR23]
  local freq_value = freq_high + freq_low

  audio.tone2.period = 32 * (2048 - freq_value)
  audio.tone2.continuous = continuous
  if restart then
    audio.tone2.base_cycle = timers.system_clock
  end
end

-- Channel 3 Enabled
io.write_logic[ports.NR30] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR30] = byte
  audio.wave3.enabled = bit32.band(byte, 0x80) ~= 0
end

-- Channel 3 Length
io.write_logic[ports.NR31] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR31] = byte
  local length_cycles = (256 - byte) * 4096
  audio.wave3.max_length = length_cycles
end

-- Channel 3 Volume
local volume_shift_mappings = {}
volume_shift_mappings[0] = 4
volume_shift_mappings[1] = 0
volume_shift_mappings[2] = 1
volume_shift_mappings[3] = 2
io.write_logic[ports.NR32] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR32] = byte
  local volume_select = bit32.rshift(bit32.band(byte, 0x60), 5)
  audio.wave3.volume_shift = volume_shift_mappings[volume_select]
end

-- Channel 3 Frequency - Low Bits
io.write_logic[ports.NR33] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR33] = byte
  local freq_high = bit32.lshift(bit32.band(io.ram[ports.NR34], 0x07), 8)
  local freq_low = byte
  local freq_value = freq_high + freq_low
  audio.wave3.period = 64 * (2048 - freq_value)
end

-- Channel 3 Frequency and Trigger - High Bits
io.write_logic[ports.NR34] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR34] = byte
  local restart = (bit32.band(byte, 0x80) ~= 0)
  local continuous = (bit32.band(byte, 0x40) == 0)
  local freq_high = bit32.lshift(bit32.band(byte, 0x07), 8)
  local freq_low = io.ram[ports.NR33]
  local freq_value = freq_high + freq_low

  audio.wave3.period = 64 * (2048 - freq_value)
  audio.wave3.continuous = continuous
  if restart then
    audio.wave3.base_cycle = timers.system_clock
  end
end

audio.tone1.update_frequency_shift = function(clock_cycle)
  local tone1 = audio.tone1
  if tone1.frequency_shift_time > 0 then
    local next_edge = tone1.base_cycle + tone1.frequency_shift_time * tone1.frequency_shift_counter
    if clock_cycle >= next_edge then
      local adjustment = bit32.rshift(tone1.frequency_shadow, tone1.frequency_shift_amount) * tone1.frequency_shift_direction
      tone1.frequency_shadow = tone1.frequency_shadow + adjustment
      if tone1.frequency_shadow >= 2048 then
        tone1.frequency_shadow = 2047
        tone1.disabled = true
      end
      io.ram[ports.NR13] = bit32.band(tone1.frequency_shadow, 0xFF)
      io.ram[ports.NR14] = bit32.rshift(bit32.band(tone1.frequency_shadow, 0x0700), 8) + bit32.band(io.ram[ports.NR14], 0xF8)
      tone1.period = 32 * (2048 - tone1.frequency_shadow)
      tone1.frequency_shift_counter = tone1.frequency_shift_counter + 1
    end
  end
end

audio.tone1.generate_sample = function(clock_cycle)
  audio.tone1.update_frequency_shift(clock_cycle)
  local tone1 = audio.tone1
  local duration = clock_cycle - tone1.base_cycle
  if tone1.continuous or (duration <= tone1.max_length) then
    local volume = tone1.volume_initial
    if tone1.volume_step_length > 0 then
      volume = volume + tone1.volume_direction * math.floor(duration / tone1.volume_step_length)
    end
    if volume > 0 then
      if volume > 0xF then
        volume = 0xF
      end
      local period_progress = (clock_cycle % tone1.period) / tone1.period
      if period_progress > tone1.duty_length then
        return volume / 0xF * -1
      else
        return volume / 0xF
      end
    end
  end
  return 0
end

audio.tone2.generate_sample = function(clock_cycle)
  local tone2 = audio.tone2
  local duration = clock_cycle - tone2.base_cycle
  if tone2.continuous or (duration <= tone2.max_length) then
    local volume = tone2.volume_initial
    if tone2.volume_step_length > 0 then
      volume = volume + tone2.volume_direction * math.floor(duration / tone2.volume_step_length)
    end
    if volume > 0 then
      if volume > 0xF then
        volume = 0xF
      end
      local period_progress = (clock_cycle % tone2.period) / tone2.period
      if period_progress > tone2.duty_length then
        return volume / 0xF * -1
      else
        return volume / 0xF
      end
    end
  end
  return 0
end

audio.wave3.generate_sample = function(clock_cycle)
  local wave3 = audio.wave3
  local duration = clock_cycle - wave3.base_cycle
  if wave3.continuous or (duration <= wave3.max_length) then
    local period = wave3.period
    local period_progress = (duration % period) / (period)
    local sample_index = math.floor(period_progress * 32)
    if sample_index > 31 then
      sample_index = 31
    end
    local byte_index = bit32.rshift(sample_index, 1)
    local sample = io.ram[0x30 + byte_index]
    -- If this is an even numbered sample, shift the high nybble
    -- to the lower nybble
    if sample_index % 2 == 0 then
      sample = bit32.rshift(sample, 4)
    end
    -- Regardless, mask out the lower nybble; this becomes our sample to play
    sample = bit32.band(sample, 0x0F)
    -- Shift the sample based on the volume parameter
    sample = bit32.rshift(sample, wave3.volume_shift)
    -- This sample will be from 0-15, we need to adjust it so that it's from -1  to 1
    sample = (sample - 8) / 8
    return sample
  end
  return 0
end

local next_sample = 0
local next_sample_cycle = 0

audio.__on_buffer_full = function(buffer) print("HI!!") end

audio.generate_pending_samples = function()
  while next_sample_cycle < timers.system_clock do
    local tone1 = audio.tone1.generate_sample(next_sample_cycle)
    local tone2 = audio.tone2.generate_sample(next_sample_cycle)
    local wave3 = audio.wave3.generate_sample(next_sample_cycle)

    local sample_left = 0
    local sample_right = 0

    local channels_enabled = io.ram[ports.NR51]
    if bit32.band(channels_enabled, 0x40) ~= 0 then
      sample_right = sample_right + wave3
    end
    if bit32.band(channels_enabled, 0x20) ~= 0 then
      sample_right = sample_right + tone2
    end
    if bit32.band(channels_enabled, 0x10) ~= 0 then
      sample_right = sample_right + tone1
    end

    if bit32.band(channels_enabled, 0x04) ~= 0 then
      sample_left = sample_left + wave3
    end
    if bit32.band(channels_enabled, 0x02) ~= 0 then
      sample_left = sample_left + tone2
    end
    if bit32.band(channels_enabled, 0x01) ~= 0 then
      sample_left = sample_left + tone1
    end

    sample_right = sample_right / 4
    sample_left = sample_left / 4

    -- Left/Right Channel Volume
    local right_volume = bit32.rshift(bit32.band(io.ram[ports.NR50], 0x70), 4)
    local left_volume = bit32.band(io.ram[ports.NR50], 0x07)

    sample_right = sample_right * right_volume / 7
    sample_left = sample_left * left_volume / 7

    audio.buffer[next_sample] = sample_left
    next_sample = next_sample + 1
    audio.buffer[next_sample] = sample_right
    next_sample = next_sample + 1
    if next_sample >= 32768 then
      audio.__on_buffer_full(audio.buffer)
      next_sample = 0
    end
    next_sample_cycle = next_sample_cycle + 128 --number of clocks per sample at 32 KHz
  end
end

audio.on_buffer_full = function(callback)
  audio.__on_buffer_full = callback
end

audio.update = function()
  audio.generate_pending_samples()
end

return audio
