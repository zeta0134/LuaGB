local audio = {}

local io = require("io")
local timers = require("timers")
local ports = io.ports

-- Note: for simplicity, we sample at 44100 Hz. Deal. I'll not bother
-- to implement any other sampling frequencies until this is more stable.

audio.buffer = {}

audio.initialize = function()
  for i = 0, 734 do
    audio.buffer[i] = 0
  end
end

audio.tone2 = {}
audio.tone2.frequency = 440 -- in Hz
audio.tone2.volume_current = 0
audio.tone2.volume_initial = 0
audio.tone2.volume_direction = 1
audio.tone2.volume_step_length = 0 -- in samples
audio.tone2.current_sample = 0      -- in samples
audio.tone2.max_length = 0          -- in samples
audio.tone2.continuous = false
audio.tone2.duty_length = .75       -- percentage, from 0-1
audio.tone2.last_edge = 0 -- in seconds (NOT samples)

local wave_patterns = {}
wave_patterns[0] = .125
wave_patterns[1] = .25
wave_patterns[2] = .50
wave_patterns[3] = .75

-- Channel 2 Sound Length / Wave Pattern Duty
io.write_logic[ports.NR21] = function(byte)
  io.ram[ports.NR21] = byte
  local wave_pattern = bit32.rshift(bit32.band(byte, 0xC0), 6)
  audio.tone2.duty_length = wave_patterns[wave_pattern]
  local length_data = bit32.band(byte, 0x3F)
  local length_seconds = (64 - length_data) * (1 / 256)
  audio.tone2.max_length = length_seconds * 44100
end

-- Channel 2 Volume Envelope
io.write_logic[ports.NR22] = function(byte)
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
  io.ram[ports.NR23] = byte
  local freq_high = bit32.lshift(bit32.band(io.ram[ports.NR23], 0x07), 8)
  local freq_value = freq_high + byte
  audio.tone2.frequency = 131072 / (2048 - freq_value)
end

audio.update = function()

end

return audio
