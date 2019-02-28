describe("Audio", function()
  describe("Registers", function()
    setup(function()
      -- Create a mock audio module with stubbed out external modules
      Audio = require("gameboy/audio/init")
      Io = require("gameboy/io")
      Memory = require("gameboy/memory")
      Timers = require("gameboy/timers")
      bit32 = require("bit")
    end)
    before_each(function()
      local modules = {}
      modules.memory = Memory.new()
      modules.io = Io.new(modules)
      modules.timers = Timers.new(modules)
      audio = Audio.new(modules)
      -- create a non-local io reference, to mock writes in tests
      io = modules.io
      ports = io.ports
      timers = modules.timers
    end)
    it("mock audio module can be created", function()
      assert.not_same(audio, nil)
    end)
    describe("Control Registers", function()
      it("Writes to NR50 should set the volume for left and right channels", function()
        io.write_logic[ports.NR50](0x77)
        assert.are_same(0x7, audio.master_volume_left)
        assert.are_same(0x7, audio.master_volume_right)
        io.write_logic[ports.NR50](0x52)
        assert.are_same(0x5, audio.master_volume_left)
        assert.are_same(0x2, audio.master_volume_right)
      end)
      it("Bit 0 of NR51 enables Tone1 on the right channel", function()
        io.write_logic[ports.NR51](0x00)
        assert.falsy(audio.tone1.master_enable_right)
        io.write_logic[ports.NR51](0x01)
        assert.truthy(audio.tone1.master_enable_right)
      end)
      it("Bit 1 of NR51 enables Tone2 on the right channel", function()
        io.write_logic[ports.NR51](0x00)
        assert.falsy(audio.tone2.master_enable_right)
        io.write_logic[ports.NR51](0x02)
        assert.truthy(audio.tone2.master_enable_right)
      end)
      it("Bit 2 of NR51 enables Wave3 on the right channel", function()
        io.write_logic[ports.NR51](0x00)
        assert.falsy(audio.wave3.master_enable_right)
        io.write_logic[ports.NR51](0x04)
        assert.truthy(audio.wave3.master_enable_right)
      end)
      it("Bit 3 of NR51 enables Noise4 on the right channel", function()
        io.write_logic[ports.NR51](0x00)
        assert.falsy(audio.noise4.master_enable_right)
        io.write_logic[ports.NR51](0x08)
        assert.truthy(audio.noise4.master_enable_right)
      end)
      it("Bit 4 of NR51 enables Tone1 on the left channel", function()
        io.write_logic[ports.NR51](0x00)
        assert.falsy(audio.tone1.master_enable_left)
        io.write_logic[ports.NR51](0x10)
        assert.truthy(audio.tone1.master_enable_left)
      end)
      it("Bit 5 of NR51 enables Tone2 on the left channel", function()
        io.write_logic[ports.NR51](0x00)
        assert.falsy(audio.tone2.master_enable_left)
        io.write_logic[ports.NR51](0x20)
        assert.truthy(audio.tone2.master_enable_left)
      end)
      it("Bit 6 of NR51 enables Wave3 on the left channel", function()
        io.write_logic[ports.NR51](0x00)
        assert.falsy(audio.wave3.master_enable_left)
        io.write_logic[ports.NR51](0x40)
        assert.truthy(audio.wave3.master_enable_left)
      end)
      it("Bit 7 of NR51 enables Noise4 on the left channel", function()
        io.write_logic[ports.NR51](0x00)
        assert.falsy(audio.noise4.master_enable_left)
        io.write_logic[ports.NR51](0x80)
        assert.truthy(audio.noise4.master_enable_left)
      end)
      it("Bit 0 of NR52 reports Tone1's length counter status", function()
        audio.tone1.length_counter.channel_enabled = false
        assert.are_same(0, bit32.band(0x01, io.read_logic[ports.NR52]()))
        audio.tone1.length_counter.channel_enabled = true
        assert.not_same(0, bit32.band(0x01, io.read_logic[ports.NR52]()))
      end)
      it("Bit 1 of NR52 reports Tone2's length counter status", function()
        audio.tone2.length_counter.channel_enabled = false
        assert.are_same(0, bit32.band(0x02, io.read_logic[ports.NR52]()))
        audio.tone2.length_counter.channel_enabled = true
        assert.not_same(0, bit32.band(0x02, io.read_logic[ports.NR52]()))
      end)
      it("Bit 2 of NR52 reports Wave3's length counter status", function()
        audio.wave3.length_counter.channel_enabled = false
        assert.are_same(0, bit32.band(0x04, io.read_logic[ports.NR52]()))
        audio.wave3.length_counter.channel_enabled = true
        assert.not_same(0, bit32.band(0x04, io.read_logic[ports.NR52]()))
      end)
      it("Bit 2 of NR52 is off if Wave3 is disabled via NR30", function()
        -- length enabled would normally signal the channel as active:
        audio.wave3.length_counter.channel_enabled = true
        -- but if the whole channel is off, it suppresses the length flag:
        audio.wave3.sampler.channel_enabled = false
        assert.are_same(0, bit32.band(0x04, io.read_logic[ports.NR52]()))
      end)
      it("Bit 3 of NR52 reports Noise4's length counter status", function()
        audio.noise4.length_counter.channel_enabled = false
        assert.are_same(0, bit32.band(0x08, io.read_logic[ports.NR52]()))
        audio.noise4.length_counter.channel_enabled = true
        assert.not_same(0, bit32.band(0x08, io.read_logic[ports.NR52]()))
      end)
      it("Bit 7 of NR52 controls master power", function()
        -- note: crazy power not available until GBA
        io.write_logic[ports.NR52](0x00)
        assert.falsy(audio.master_enable)
        io.write_logic[ports.NR52](0x80)
        assert.truthy(audio.master_enable)
      end)
    end)
    describe("Tone 1", function()
      it("writes to NR10 set the sweep period", function()
        audio.tone1.generator.sweep_timer.period = 0
        io.write_logic[ports.NR10](0x70)
        assert.are_same(0x7, audio.tone1.generator.sweep_timer.period)
      end)
      it("writes to NR10 set the sweep negate mode", function()
        audio.tone1.generator.sweep_negate = false
        io.write_logic[ports.NR10](0x08)
        assert.truthy(audio.tone1.generator.sweep_negate)
        io.write_logic[ports.NR10](0x00)
        assert.falsy(audio.tone1.generator.sweep_negate)
      end)
      it("writes to NR10 set the sweep shift", function()
        audio.tone1.generator.sweep_shift = 0
        io.write_logic[ports.NR10](0x07)
        assert.are_same(0x7, audio.tone1.generator.sweep_shift)
      end)
      it("trigger writes to NR14 update the frequency shadow register", function()
        audio.tone1.generator.frequency_shadow = 0
        io.write_logic[ports.NR13](0x22)
        io.write_logic[ports.NR14](0x81)
        assert.are_same(0x0122, audio.tone1.generator.frequency_shadow)
      end)
      it("trigger writes to NR14 re-enable the square generator", function()
        audio.tone1.generator.channel_enabled = false
        io.write_logic[ports.NR14](0x80)
        assert.truthy(audio.tone1.generator.channel_enabled)
      end)
      it("trigger writes to NR14 reload the sweep timer", function()
        audio.tone1.generator.sweep_timer:reload(4)
        audio.tone1.generator.sweep_timer.period = 7
        assert.are_same(4, audio.tone1.generator.sweep_timer:remainingClocks())
        io.write_logic[ports.NR14](0x80) --trigger note
        assert.are_same(7, audio.tone1.generator.sweep_timer:remainingClocks())
      end)
      it("trigger writes to NR14 use the low bits from NR13 for the period", function()
        -- Make sure writes to each of the low / high byte use the value from the other half:
        audio.tone1.generator.timer.period = 0
        io.write_logic[ports.NR13](0x22)
        io.write_logic[ports.NR14](0x81)
        assert.are_same((2048 - 0x0122) * 4, audio.tone1.generator.timer.period)
      end)
      it("writes to NR13 update the period immediately", function()
        audio.tone1.generator.timer.period = 0
        io.write_logic[ports.NR13](0x44)
        assert.are_same((2048 - 0x0044) * 4, audio.tone1.generator.timer.period)
      end)
      it("non-triggered writes to NR14 still update the period", function()
        audio.tone1.generator.timer.period = 0
        io.write_logic[ports.NR14](0x03)
        assert.are_same((2048 - 0x0300) * 4, audio.tone1.generator.timer.period)
      end)
      it("writes to NR11 set the waveform duty on the next NR14 trigger", function()
        audio.tone1.generator.waveform = 0x00
        io.write_logic[ports.NR11](bit32.lshift(0x0, 6))
        io.write_logic[ports.NR14](0x80) -- trigger a new note
        assert.are_same(0x01, audio.tone1.generator.waveform)
        io.write_logic[ports.NR11](bit32.lshift(0x1, 6))
        io.write_logic[ports.NR14](0x80) -- trigger a new note
        assert.are_same(0x81, audio.tone1.generator.waveform)
        io.write_logic[ports.NR11](bit32.lshift(0x2, 6))
        io.write_logic[ports.NR14](0x80) -- trigger a new note
        assert.are_same(0x87, audio.tone1.generator.waveform)
        io.write_logic[ports.NR11](bit32.lshift(0x3, 6))
        io.write_logic[ports.NR14](0x80) -- trigger a new note
        assert.are_same(0x7E, audio.tone1.generator.waveform)
      end)
    end)
    describe("Tone 2", function()
      it("trigger writes to NR24 use the low bits from NR23 for the period", function()
        -- Make sure writes to each of the low / high byte use the value from the other half:
        audio.tone2.generator.timer.period = 0
        io.write_logic[ports.NR23](0x22)
        io.write_logic[ports.NR24](0x81)
        assert.are_same((2048 - 0x0122) * 4, audio.tone2.generator.timer.period)
      end)
      it("writes to NR23 update the period immediately", function()
        audio.tone2.generator.timer.period = 0
        io.write_logic[ports.NR23](0x44)
        assert.are_same((2048 - 0x0044) * 4, audio.tone2.generator.timer.period)
      end)
      it("non-triggered writes to NR24 still update the period", function()
        audio.tone2.generator.timer.period = 0
        io.write_logic[ports.NR24](0x03)
        assert.are_same((2048 - 0x0300) * 4, audio.tone2.generator.timer.period)
      end)
      it("writes to NR21 set the waveform duty on the next NR14 trigger", function()
        audio.tone2.generator.waveform = 0x00
        io.write_logic[ports.NR21](bit32.lshift(0x0, 6))
        io.write_logic[ports.NR24](0x80) -- trigger a new note
        assert.are_same(0x01, audio.tone2.generator.waveform)
        io.write_logic[ports.NR21](bit32.lshift(0x1, 6))
        io.write_logic[ports.NR24](0x80) -- trigger a new note
        assert.are_same(0x81, audio.tone2.generator.waveform)
        io.write_logic[ports.NR21](bit32.lshift(0x2, 6))
        io.write_logic[ports.NR24](0x80) -- trigger a new note
        assert.are_same(0x87, audio.tone2.generator.waveform)
        io.write_logic[ports.NR21](bit32.lshift(0x3, 6))
        io.write_logic[ports.NR24](0x80) -- trigger a new note
        assert.are_same(0x7E, audio.tone2.generator.waveform)
      end)
    end)
    describe("Wave 3", function()
      it("writes to NR30 enable / disable the channel", function()
        audio.wave3.sampler.channel_enabled = false
        io.write_logic[ports.NR30](0x80)
        assert.are_same(true, audio.wave3.sampler.channel_enabled)
        io.write_logic[ports.NR30](0x00)
        assert.are_same(false, audio.wave3.sampler.channel_enabled)
      end)
      it("trigger writes to NR34 use the low bits from NR33 for the period", function()
        -- Make sure writes to each of the low / high byte use the value from the other half:
        audio.wave3.sampler.timer.period = 0
        io.write_logic[ports.NR33](0x22)
        io.write_logic[ports.NR34](0x81)
        assert.are_same((2048 - 0x0122) * 2, audio.wave3.sampler.timer.period)
      end)
      it("writes to NR33 update the period immediately", function()
        audio.wave3.sampler.timer.period = 0
        io.write_logic[ports.NR33](0x44)
        assert.are_same((2048 - 0x0044) * 2, audio.wave3.sampler.timer.period)
      end)
      it("non-triggered writes to NR34 still update the period", function()
        audio.wave3.sampler.timer.period = 0
        io.write_logic[ports.NR34](0x03)
        assert.are_same((2048 - 0x0300) * 2, audio.wave3.sampler.timer.period)
      end)
      it("writes to NR32 set the wave's volume accordingly", function()
        audio.wave3.sampler.volume_shift = 0
        io.write_logic[ports.NR32](0x00) -- [-00-----]
        assert.are_same(audio.wave3.sampler.volume_shift, 4)
        io.write_logic[ports.NR32](0x20) -- [-01-----]
        assert.are_same(audio.wave3.sampler.volume_shift, 0)
        io.write_logic[ports.NR32](0x40) -- [-10-----]
        assert.are_same(audio.wave3.sampler.volume_shift, 1)
        io.write_logic[ports.NR32](0x60) -- [-11-----]
        assert.are_same(audio.wave3.sampler.volume_shift, 2)
      end)
      it("trigger writes to NR34 reset the sample position", function()
        audio.wave3.sampler.position = 5
        io.write_logic[ports.NR34](0x80) -- trigger a new note
        assert.are_same(audio.wave3.sampler.position, 0)
      end)
    end)
    describe("Noise 4", function()
      it("writes to NR43 set the period according to divisor code", function()
        -- Note: we use a clock shift of 0, so we should essentially get the
        -- unmodified entry in the divisor table as the period
        io.write_logic[ports.NR43](0x0)
        assert.are_same(audio.noise4.lfsr.timer.period, 8)
        io.write_logic[ports.NR43](0x1)
        assert.are_same(audio.noise4.lfsr.timer.period, 16)
        io.write_logic[ports.NR43](0x2)
        assert.are_same(audio.noise4.lfsr.timer.period, 32)
        io.write_logic[ports.NR43](0x3)
        assert.are_same(audio.noise4.lfsr.timer.period, 48)
        io.write_logic[ports.NR43](0x4)
        assert.are_same(audio.noise4.lfsr.timer.period, 64)
        io.write_logic[ports.NR43](0x5)
        assert.are_same(audio.noise4.lfsr.timer.period, 80)
        io.write_logic[ports.NR43](0x6)
        assert.are_same(audio.noise4.lfsr.timer.period, 96)
        io.write_logic[ports.NR43](0x7)
        assert.are_same(audio.noise4.lfsr.timer.period, 112)
      end)
      it("writes to NR43 shift the period to the left", function()
        -- Note: we'll do all our tests here with the shortest period, 8
        for i = 0, 0xF do
          io.write_logic[ports.NR43](bit32.lshift(i, 4))
          assert.are_same(audio.noise4.lfsr.timer.period, bit32.lshift(8, i))
        end
      end)
      it("writes to NR43 set the width mode based on bit 3", function()
        io.write_logic[ports.NR43](0x00)
        assert.are_same(0, audio.noise4.lfsr.width_mode)
        io.write_logic[ports.NR43](0x08)
        assert.are_same(1, audio.noise4.lfsr.width_mode)
      end)
    end)
    it("trigger writes to NR44 reset the LFSR", function()
      audio.noise4.lfsr.current_value = 0x0
      io.write_logic[ports.NR44](0x80) -- trigger a new note
      assert.are_same(audio.noise4.lfsr.current_value, 0x7FFF)
    end)
  end)
end)