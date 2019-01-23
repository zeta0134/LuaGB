local bit32 = require("bit")

local Audio = {}

function Audio.new(modules)
  local io = modules.io
  local timers = modules.timers
  local ports = io.ports

  local audio = {}

  -- Note: for simplicity, we sample at 44100 Hz. Deal. I'll not bother
  -- to implement any other sampling frequencies until this is more stable.

  audio.buffer = {}
  audio.tone1 = {}
  audio.tone2 = {}
  audio.wave3 = {}
  audio.noise4 = {}

  local next_sample = 0
  local next_sample_cycle = 0

  audio.reset = function()
    audio.tone1.debug_disabled = false
    audio.tone1.period = 128 -- in cycles
    audio.tone1.volume_initial = 0
    audio.tone1.volume_direction = 1
    audio.tone1.volume_step_length = 0 -- in cycles
    audio.tone1.max_length = 0          -- in cycles
    audio.tone1.continuous = false
    audio.tone1.duty_length = .75       -- percentage, from 0-1
    audio.tone1.wave_pattern = 0
    audio.tone1.base_cycle = 0
    audio.tone1.frequency_last_update = 0 -- in cycles
    audio.tone1.wave_duty_counter = 0
    audio.tone1.period_counter = 0
    audio.tone1.frequency_target = 0
    audio.tone1.frequency_shadow = 0
    audio.tone1.frequency_shift_time = 0 -- in cycles, 0 == disabled
    audio.tone1.frequency_shift_counter = 0 -- should be reset on trigger
    audio.tone1.frequency_shift_direction = 1
    audio.tone1.frequency_shift_amount = 0
    audio.tone1.active = false

    audio.tone2.debug_disabled = false
    audio.tone2.period = 128 -- in cycles
    audio.tone2.volume_initial = 0
    audio.tone2.volume_direction = 1
    audio.tone2.volume_step_length = 0 -- in cycles
    audio.tone2.max_length = 0          -- in cycles
    audio.tone2.continuous = false
    audio.tone2.duty_length = .75       -- percentage, from 0-1
    audio.tone2.wave_pattern = 0
    audio.tone2.base_cycle = 0
    audio.tone2.frequency_last_update = 0 -- in cycles
    audio.tone2.period_counter = 0
    audio.tone2.wave_duty_counter = 0
    audio.tone2.frequency_shadow = 0
    audio.tone2.active = false

    audio.wave3.debug_disabled = false
    audio.wave3.enabled = false
    audio.wave3.max_length = 0 -- in cycles
    audio.wave3.volume_shift = 0
    audio.wave3.period = 0 -- in cycles
    audio.wave3.continuous = false
    audio.wave3.base_cycle = 0
    audio.wave3.frequency_last_update = 0 -- in cycles
    audio.wave3.period_counter = 0
    audio.wave3.sample_index = 0
    audio.wave3.frequency_shadow = 0
    audio.wave3.active = false

    audio.noise4.debug_disabled = false
    audio.noise4.volume_initial = 0
    audio.noise4.volume_direction = 1
    audio.noise4.volume_step_length = 0 -- in cycles
    audio.noise4.max_length = 0          -- in cycles
    audio.noise4.continuous = false
    audio.noise4.base_cycle = 0
    audio.noise4.polynomial_period = 16
    audio.noise4.polynomial_lfsr = 0x7FFF -- 15 bits
    audio.noise4.polynomial_last_shift = 0 -- in cycles
    audio.noise4.polynomial_wide = true
    audio.noise4.active = false

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

  local wave_patterns = {}
  wave_patterns[0] = .125
  wave_patterns[1] = .25
  wave_patterns[2] = .50
  wave_patterns[3] = .75

  local wave_pattern_tables = {}
  wave_pattern_tables[0] = {0,0,0,0,0,0,0,1}
  wave_pattern_tables[1] = {1,0,0,0,0,0,0,1}
  wave_pattern_tables[2] = {1,0,0,0,0,1,1,1}
  wave_pattern_tables[3] = {0,1,1,1,1,1,1,0}

  io.read_logic[0x26] = function()
    local high_nybble = bit32.band(0xF0, io.ram[0x26])
    local low_nybble = 0
    if audio.tone1.active then
      low_nybble = low_nybble + 0x01
    end
    if audio.tone2.active then
      low_nybble = low_nybble + 0x02
    end
    if audio.wave3.active then
      low_nybble = low_nybble + 0x04
    end
    if audio.noise4.active then
      low_nybble = low_nybble + 0x08
    end
    return high_nybble + low_nybble
  end

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
    audio.tone1.wave_pattern = wave_pattern
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
    audio.tone1.frequency_shadow = freq_value
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
      audio.tone1.active = true
    end
    audio.tone1.frequency_shadow = freq_value
    audio.tone1.period_conter = (2048 - freq_value)
    audio.tone1.frequency_shift_counter = 0
  end

  -- Channel 2 Sound Length / Wave Pattern Duty
  io.write_logic[ports.NR21] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR21] = byte
    local wave_pattern = bit32.rshift(bit32.band(byte, 0xC0), 6)
    audio.tone2.duty_length = wave_patterns[wave_pattern]
    audio.tone2.wave_pattern = wave_pattern
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
    audio.tone2.frequency_shadow = freq_value
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
    audio.tone2.period_conter = (2048 - freq_value)
    audio.tone2.frequency_shadow = freq_value
    audio.tone2.continuous = continuous
    if restart then
      audio.tone2.base_cycle = timers.system_clock
      audio.tone2.active = true
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
    audio.wave3.frequency_shadow = freq_value
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
    audio.wave3.period_conter = (2048 - freq_value)
    audio.wave3.frequency_shadow = freq_value
    audio.wave3.continuous = continuous
    if restart then
      audio.wave3.base_cycle = timers.system_clock
      audio.wave3.sample_index = 0
      audio.wave3.active = true
    end
  end

  -- Channel 4 Length
  io.write_logic[ports.NR41] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR41] = byte
    local wave_pattern = bit32.rshift(bit32.band(byte, 0xC0), 6)
    audio.noise4.duty_length = wave_patterns[wave_pattern]
    local length_data = bit32.band(byte, 0x3F)
    local length_cycles = (64 - length_data) * 16384
    audio.noise4.max_length = length_cycles
  end

  -- Channel 4 Volume Envelope
  io.write_logic[ports.NR42] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR42] = byte
    audio.noise4.volume_initial = bit32.rshift(bit32.band(byte, 0xF0), 4)
    local direction = bit32.band(byte, 0x08)
    if direction > 0 then
      audio.noise4.volume_direction = 1
    else
      audio.noise4.volume_direction = -1
    end
    local envelope_step_data = bit32.band(byte, 0x07)
    local envelope_step_cycles = envelope_step_data * 65536
    audio.noise4.volume_step_length = envelope_step_cycles
  end

  local polynomial_divisors = {}
  polynomial_divisors[0] = 8
  polynomial_divisors[1] = 16
  polynomial_divisors[2] = 32
  polynomial_divisors[3] = 48
  polynomial_divisors[4] = 64
  polynomial_divisors[5] = 80
  polynomial_divisors[6] = 96
  polynomial_divisors[7] = 112

  -- Channel 4 Polynomial Counter
  io.write_logic[ports.NR43] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR43] = byte
    local shift_clock_frequency = bit32.rshift(bit32.band(byte, 0xF0), 4)
    local wide_step = bit32.band(byte, 0x08) == 0
    local dividing_ratio = polynomial_divisors[bit32.band(byte, 0x07)]

    -- Maybe?
    audio.noise4.polynomial_period = bit32.lshift(dividing_ratio, shift_clock_frequency)
    audio.noise4.polynomial_wide = wide_step
  end

  -- Channel 4 Trigger
  io.write_logic[ports.NR44] = function(byte)
    audio.generate_pending_samples()
    io.ram[ports.NR44] = byte
    local restart = (bit32.band(byte, 0x80) ~= 0)
    local continuous = (bit32.band(byte, 0x40) == 0)

    audio.noise4.continuous = continuous
    if restart then
      audio.noise4.base_cycle = timers.system_clock
      -- Reset the LSFR to all 1's
      audio.noise4.polynomial_lfsr = 0x7FFF
      audio.noise4.active = true
    end
  end

  audio.tone1.update_frequency_shift = function(clock_cycle)
    local tone1 = audio.tone1
    -- A shift_time of 0 disables frequency shifting entirely
    if tone1.frequency_shift_time > 0 then
      local next_edge = tone1.base_cycle + tone1.frequency_shift_time * tone1.frequency_shift_counter
      if clock_cycle >= next_edge then
        local adjustment = bit32.rshift(tone1.frequency_shadow, tone1.frequency_shift_amount) * tone1.frequency_shift_direction
        tone1.frequency_shadow = tone1.frequency_shadow + adjustment
        if tone1.frequency_shadow >= 2048 then
          tone1.frequency_shadow = 2047
          tone1.active = false
        end
        tone1.period = 32 * (2048 - tone1.frequency_shadow)
        tone1.frequency_shift_counter = tone1.frequency_shift_counter + 1
      end
    end
  end

  audio.noise4.update_lfsr = function(clock_cycle)
    --print(clock_cycle - audio.noise4.polynomial_last_shift)
    --print(audio.noise4.polynomial_period)
    while clock_cycle - audio.noise4.polynomial_last_shift > audio.noise4.polynomial_period do
      local lfsr = audio.noise4.polynomial_lfsr
      -- Grab the lowest two bits in LSFR and XOR them together
      local bit0 = bit32.band(lfsr, 0x1)
      local bit1 = bit32.rshift(bit32.band(lfsr, 0x2), 1)
      local xor = bit32.bxor(bit0, bit1)
      -- Shift LSFR down by one
      lfsr = bit32.rshift(lfsr, 1)
      -- Place the XOR'd bit into the high bit (14) always
      xor = bit32.lshift(xor, 14)
      lfsr = bit32.bor(xor, lfsr)
      if not audio.noise4.polynomial_wide then
        -- place the XOR'd bit into bit 6 as well
        xor = bit32.rshift(xor, 8)
        lfsr = bit32.bor(xor, bit32.band(lfsr, 0x7FBF))
      end
      audio.noise4.polynomial_last_shift = audio.noise4.polynomial_last_shift + audio.noise4.polynomial_period
      audio.noise4.polynomial_lfsr = lfsr
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

        while clock_cycle > tone1.frequency_last_update + 4 do
          tone1.period_counter = tone1.period_counter - 1
          if tone1.period_counter <= 0 then
            tone1.period_counter = (2048 - tone1.frequency_shadow)
            tone1.wave_duty_counter = tone1.wave_duty_counter + 1
            if tone1.wave_duty_counter >= 8 then
              tone1.wave_duty_counter = 0
            end
          end
          tone1.frequency_last_update = tone1.frequency_last_update + 4
        end

        if wave_pattern_tables[tone1.wave_pattern][tone1.wave_duty_counter + 1] == 0 then
          return volume / 0xF * -1
        else
          return volume / 0xF
        end
      end
    else
      audio.tone1.active = false
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

        while clock_cycle > tone2.frequency_last_update + 4 do
          tone2.period_counter = tone2.period_counter - 1
          if tone2.period_counter <= 0 then
            tone2.period_counter = (2048 - tone2.frequency_shadow)
            tone2.wave_duty_counter = tone2.wave_duty_counter + 1
            if tone2.wave_duty_counter >= 8 then
              tone2.wave_duty_counter = 0
            end
          end
          tone2.frequency_last_update = tone2.frequency_last_update + 4
        end

        if wave_pattern_tables[tone2.wave_pattern][tone2.wave_duty_counter + 1] == 0 then
          return volume / 0xF * -1
        else
          return volume / 0xF
        end
      end
    else
      tone2.active = false
    end
    return 0
  end

  audio.wave3.generate_sample = function(clock_cycle)
    local wave3 = audio.wave3
    local duration = clock_cycle - wave3.base_cycle
    if wave3.enabled then
      if wave3.continuous or (duration <= wave3.max_length) then
        --local period = wave3.period
        --local period_progress = (duration % period) / (period)
        --local sample_index = math.floor(period_progress * 32)
        while clock_cycle > wave3.frequency_last_update + 2 do
          wave3.period_counter = wave3.period_counter - 1
          if wave3.period_counter <= 0 then
            wave3.period_counter = (2048 - wave3.frequency_shadow)
            wave3.sample_index = wave3.sample_index + 1
            if wave3.sample_index >= 32 then
              wave3.sample_index = 0
            end
          end
          wave3.frequency_last_update = wave3.frequency_last_update + 2
        end

        local byte_index = bit32.rshift(wave3.sample_index, 1)
        local sample = io.ram[0x30 + byte_index]
        -- If this is an even numbered sample, shift the high nybble
        -- to the lower nybble
        if wave3.sample_index % 2 == 0 then
          sample = bit32.rshift(sample, 4)
        end
        -- Regardless, mask out the lower nybble; this becomes our sample to play
        sample = bit32.band(sample, 0x0F)
        -- Shift the sample based on the volume parameter
        sample = bit32.rshift(sample, wave3.volume_shift)
        -- This sample will be from 0-15, we need to adjust it so that it's from -1  to 1
        sample = (sample - 8) / 8
        return sample
      else
        wave3.active = false
      end
    else
      wave3.active = false
    end
    return 0
  end

  audio.noise4.generate_sample = function(clock_cycle)
    audio.noise4.update_lfsr(clock_cycle)
    local noise4 = audio.noise4
    local duration = clock_cycle - noise4.base_cycle
    if noise4.continuous or (duration <= noise4.max_length) then
      local volume = noise4.volume_initial
      if noise4.volume_step_length > 0 then
        volume = volume + noise4.volume_direction * math.floor(duration / noise4.volume_step_length)
      end
      if volume > 0 then
        if volume > 0xF then
          volume = 0xF
        end
        -- Output high / low is based on the INVERTED low bit of LFSR
        if bit32.band(noise4.polynomial_lfsr, 0x1) == 0 then
          return volume / 0xF
        else
          return volume / 0xF * -1
        end
      end
    else
      noise4.active = false
    end
    return 0
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

  audio.debug.enabled = false

  audio.generate_pending_samples = function()
    while next_sample_cycle < timers.system_clock do
      local tone1  = audio.tone1.generate_sample(next_sample_cycle)
      local tone2  = audio.tone2.generate_sample(next_sample_cycle)
      local wave3  = audio.wave3.generate_sample(next_sample_cycle)
      local noise4 = audio.noise4.generate_sample(next_sample_cycle)

      local sample_left = 0
      local sample_right = 0

      local channels_enabled = io.ram[ports.NR51]
      if bit32.band(channels_enabled, 0x80) ~= 0 and not audio.noise4.debug_disabled then
        sample_right = sample_right + noise4
      end
      if bit32.band(channels_enabled, 0x40) ~= 0 and not audio.wave3.debug_disabled  then
        sample_right = sample_right + wave3
      end
      if bit32.band(channels_enabled, 0x20) ~= 0 and not audio.tone2.debug_disabled  then
        sample_right = sample_right + tone2
      end
      if bit32.band(channels_enabled, 0x10) ~= 0 and not audio.tone1.debug_disabled  then
        sample_right = sample_right + tone1
      end

      if bit32.band(channels_enabled, 0x08) ~= 0 and not audio.noise4.debug_disabled  then
        sample_left = sample_left + noise4
      end
      if bit32.band(channels_enabled, 0x04) ~= 0 and not audio.wave3.debug_disabled  then
        sample_left = sample_left + wave3
      end
      if bit32.band(channels_enabled, 0x02) ~= 0 and not audio.tone2.debug_disabled  then
        sample_left = sample_left + tone2
      end
      if bit32.band(channels_enabled, 0x01) ~= 0 and not audio.tone1.debug_disabled  then
        sample_left = sample_left + tone1
      end

      sample_right = sample_right / 4
      sample_left = sample_left / 4

      if audio.debug.enabled then
        -- Debug in mono
        audio.save_debug_samples(tone1, tone2, wave3, noise4, (tone1 + tone2 + wave3 + noise4) / 4)
      end

      -- Left/Right Channel Volume
      local right_volume = bit32.rshift(bit32.band(io.ram[ports.NR50], 0x70), 4)
      local left_volume = bit32.band(io.ram[ports.NR50], 0x07)

      sample_right = sample_right * right_volume / 7
      sample_left = sample_left * left_volume / 7

      audio.buffer[next_sample] = sample_left
      next_sample = next_sample + 1
      audio.buffer[next_sample] = sample_right
      next_sample = next_sample + 1
      if next_sample >= 1024 then
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
end

return Audio
