local bit32 = require("bit")

local Registers = require("gameboy/audio/registers")
local FrameSequencer = require("gameboy/audio/frame_sequencer")
local LengthCounter = require("gameboy/audio/length_counter")
local SquareWaveGenerator = require("gameboy/audio/square_wave_generator")
local VolumeEnvelope = require("gameboy/audio/volume_envelope")
local WaveSampler = require("gameboy/audio/wave_sampler")

local Audio = {}

-- Note: for simplicity, we sample at 32768 Hz. Deal. I'll not bother
-- to implement any other sampling frequencies until this is more stable.

function Audio.new(modules)
  local io = modules.io
  local timers = modules.timers
  local ports = io.ports

  local audio = {}

  audio.registers = Registers.new(audio, modules)

  audio.buffer = {}
  audio.tone1 = {
    generator=SquareWaveGenerator:new(),
    volume_envelope=VolumeEnvelope:new(),
    length_counter=LengthCounter:new()
  }
  audio.tone1.generator.timer:reload(1)
  audio.tone1.generator.waveform = 0x0F

  audio.tone2 = {
    generator=SquareWaveGenerator:new(),
    volume_envelope=VolumeEnvelope:new(),
    length_counter=LengthCounter:new()
  }
  audio.tone2.generator.timer:reload(1)
  audio.tone2.generator.waveform = 0x0F

  audio.wave3 = {
    sampler=WaveSampler:new(),
    length_counter=LengthCounter:new(),
  }
  audio.wave3.sampler:onRead(function(sample_byte)
    return io.ram[0x30 + sample_byte]
  end)

  audio.noise4 = {}

  audio.frame_sequencer = FrameSequencer:new()
  audio.frame_sequencer.timer:reload(8192)

  audio.frame_sequencer:onVolume(function()
    audio.tone1.volume_envelope.timer:clock()
    audio.tone2.volume_envelope.timer:clock()
  end)

  audio.frame_sequencer:onLength(function()
    audio.tone1.length_counter:clock()
    audio.tone2.length_counter:clock()
    audio.wave3.length_counter:clock()
  end)

  audio.frame_sequencer:onSweep(function()
    audio.tone1.generator.sweep_timer:clock()
  end)

  audio.next_sample = 0
  audio.next_sample_cycle = 0

  audio.reset = function()
    next_sample = 0
    next_sample_cycle = 0

    -- initialize audio registers
    -- pulled from: http://bgb.bircd.org/pandocs.htm#powerupsequence
    io.ram[0x10] = 0x80
    io.ram[0x11] = 0xBF
    io.ram[0x12] = 0xF3
    io.ram[0x14] = 0xBF
    io.ram[0x16] = 0x3F
    io.ram[0x17] = 0x00
    io.ram[0x19] = 0xBF
    io.ram[0x1A] = 0x7F
    io.ram[0x1B] = 0xFF
    io.ram[0x1C] = 0x9F
    io.ram[0x1E] = 0xBF
    io.ram[0x20] = 0xFF
    io.ram[0x21] = 0x00
    io.ram[0x22] = 0x00
    io.ram[0x23] = 0xBF
    io.ram[0x24] = 0x77
    io.ram[0x25] = 0xF3
    io.ram[0x26] = 0xF1
  end

  audio.initialize = function()
    for i = 0, 32768 do
      audio.buffer[i] = 0
    end

    audio.reset()
  end

  audio.save_state = function()
    local state = {}
    state.next_sample_cycle = next_sample_cycle
    return state
  end

  audio.load_state = function(state)
    next_sample_cycle = state.next_sample_cycle
  end

  audio.__on_buffer_full = function(buffer) end

  audio.debug = {}
  audio.debug.current_sample = 0
  audio.debug.max_samples = 128
  audio.debug.tone1 = {}
  audio.debug.tone2 = {}
  audio.debug.wave3 = {}
  audio.debug.noise4 = {}
  audio.debug.final = {}
  for i = 0, audio.debug.max_samples do
    audio.debug.tone1[i] = 0
    audio.debug.tone2[i] = 0
    audio.debug.wave3[i] = 0
    audio.debug.noise4[i] = 0
    audio.debug.final[i] = 0
  end

  audio.save_debug_samples = function(tone1, tone2, wave3, noise4, final)
    local debug = audio.debug
    debug.tone1[debug.current_sample] = tone1
    debug.tone2[debug.current_sample] = tone2
    debug.wave3[debug.current_sample] = wave3
    debug.noise4[debug.current_sample] = noise4
    debug.final[debug.current_sample] = final
    debug.current_sample = debug.current_sample + 1
    if debug.current_sample >= debug.max_samples then
      debug.current_sample = 0
    end
  end

  audio.generate_pending_samples = function()
    while audio.next_sample_cycle < timers.system_clock do
      -- Clock the period timers at 4 MHz
      audio.tone1.generator.timer:advance(128)
      audio.tone2.generator.timer:advance(128)
      audio.wave3.sampler.timer:advance(128)

      -- Clock the frame sequencer at 4 MHz
      audio.frame_sequencer.timer:advance(128)

      
      local tone1 = audio.tone1.generator:output()
      tone1 = audio.tone1.length_counter:output(tone1)
      tone1 = audio.tone1.volume_envelope:output(tone1)
      tone1 = tone1 / 15 - 0.5

      local tone2 = audio.tone2.generator:output()
      tone2 = audio.tone2.length_counter:output(tone2)
      tone2 = audio.tone2.volume_envelope:output(tone2)
      tone2 = tone2 / 15 - 0.5

      local wave3 = audio.wave3.sampler:output()
      wave3 = audio.wave3.length_counter:output(wave3)
      wave3 = wave3 / 15 - 0.5

      local sample = (tone1 + tone2 + wave3) / 3

      -- Cheat further, and use that sample directly
      audio.buffer[next_sample] = sample
      next_sample = next_sample + 1
      audio.buffer[next_sample] = sample
      next_sample = next_sample + 1

      if next_sample >= 1024 then
        audio.__on_buffer_full(audio.buffer)
        next_sample = 0
      end
      audio.next_sample_cycle = audio.next_sample_cycle + 128 --number of clocks per sample at 32 KHz
    end
  end

  audio.on_buffer_full = function(callback)
    audio.__on_buffer_full = callback
  end

  audio.update = function()
    audio.generate_pending_samples()
  end

  return audio
end

return Audio
