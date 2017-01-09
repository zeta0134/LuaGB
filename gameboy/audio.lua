local bit32 = require("bit")

local io = require("gameboy/io")
local timers = require("gameboy/timers")
local ports = io.ports

local audio = {}

-- Note: for simplicity, we sample at 44100 Hz. Deal. I'll not bother
-- to implement any other sampling frequencies until this is more stable.

audio.buffer = {}

audio.initialize = function()
  for i = 0, 4096 do
    audio.buffer[i] = 0
  end
end

audio.tone2 = {}
audio.tone2.period = 128 -- in cycles
audio.tone2.volume_initial = 0
audio.tone2.volume_direction = 1
audio.tone2.volume_step_length = 0 -- in samples
audio.tone2.max_length = 0          -- in samples
audio.tone2.continuous = false
audio.tone2.duty_length = .75       -- percentage, from 0-1
audio.tone2.base_cycle = 0

local wave_patterns = {}
wave_patterns[0] = .125
wave_patterns[1] = .25
wave_patterns[2] = .50
wave_patterns[3] = .75

-- Channel 2 Sound Length / Wave Pattern Duty
io.write_logic[ports.NR21] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR21] = byte
  local wave_pattern = bit32.rshift(bit32.band(byte, 0xC0), 6)
  audio.tone2.duty_length = wave_patterns[wave_pattern]
  local length_data = bit32.band(byte, 0x3F)
  local length_seconds = (64 - length_data) * (1 / 256)
  audio.tone2.max_length = length_seconds * 44100
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
  local envelope_step_seconds = envelope_step_data * (1 / 64)
  audio.tone2.volume_step_length = envelope_step_seconds * 44100
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

io.write_logic[ports.NR24] = function(byte)
  audio.generate_pending_samples()
  io.ram[ports.NR24] = byte
  local restart = (bit32.band(byte, 0x80) ~= 0)
  local continuous = (bit32.band(byte, 0x40) ~= 0)
  local freq_high = bit32.lshift(bit32.band(byte, 0x07), 8)
  local freq_low = io.ram[ports.NR23]
  local freq_value = freq_high + freq_low

  audio.tone2.period = 32 * (2048 - freq_value)
  audio.tone2.continuous = continuous
  if restart then
    audio.tone2.base_cycle = timers.system_clock
  end
end

audio.tone2.generate_sample = function(clock_cycle)
  -- TODO: handle volume, sweep, max length
  -- For now: just generate a tone! Let it play, it'll sound gross!

  local period_progress = (clock_cycle % audio.tone2.period) / audio.tone2.period
  if period_progress > audio.tone2.duty_length then
    return -1.0
  else
    return 1.0
  end
end

local next_sample = 0
local next_sample_cycle = 0

audio.__on_buffer_full = function(buffer) print("HI!!") end

audio.generate_pending_samples = function()
  while next_sample_cycle < timers.system_clock do
    audio.buffer[next_sample] = audio.tone2.generate_sample(next_sample_cycle)
    next_sample = next_sample + 1
    if next_sample >= 2048 then
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
