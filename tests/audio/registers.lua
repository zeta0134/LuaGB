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
    describe("Tone 1", function()
      it("writes to NR10 set the sweep period", function()
        audio.tone1.generator.sweep_timer:setPeriod(0)
        io.write_logic[ports.NR10](0x70)
        assert.are_same(0x7, audio.tone1.generator.sweep_timer:period())
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
        audio.tone1.generator.sweep_timer:setPeriod(7)
        assert.are_same(4, audio.tone1.generator.sweep_timer:remainingClocks())
        io.write_logic[ports.NR14](0x80) --trigger note
        assert.are_same(7, audio.tone1.generator.sweep_timer:remainingClocks())
      end)
      it("trigger writes to NR14 use the low bits from NR13 for the period", function()
        -- Make sure writes to each of the low / high byte use the value from the other half:
        audio.tone1.generator.timer:setPeriod(0)
        io.write_logic[ports.NR13](0x22)
        io.write_logic[ports.NR14](0x81)
        assert.are_same((2048 - 0x0122) * 4, audio.tone1.generator.timer:period())
      end)
      it("writes to NR13 update the period immediately", function()
        audio.tone1.generator.timer:setPeriod(0)
        io.write_logic[ports.NR13](0x44)
        assert.are_same((2048 - 0x0044) * 4, audio.tone1.generator.timer:period())
      end)
      it("non-triggered writes to NR14 still update the period", function()
        audio.tone1.generator.timer:setPeriod(0)
        io.write_logic[ports.NR14](0x03)
        assert.are_same((2048 - 0x0300) * 4, audio.tone1.generator.timer:period())
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
      it("writes to NR11 reload the length counter with (64-L)", function()
        audio.tone1.length_counter.counter = 0
        io.write_logic[ports.NR11](0x3F)
        assert.are_same(audio.tone1.length_counter.counter, 1)
        io.write_logic[ports.NR11](0x00)
        assert.are_same(audio.tone1.length_counter.counter, 64)
      end)
      it("writes to NR14 enable / disable the length counter", function()
        io.write_logic[ports.NR14](0x40)
        assert.truthy(audio.tone1.length_counter.length_enabled)
        io.write_logic[ports.NR14](0x00)
        assert.falsy(audio.tone1.length_counter.length_enabled)
      end)
      it("triggers on NR14 enable the channel", function()
        audio.tone1.length_counter.channel_enabled = false
        io.write_logic[ports.NR14](0x80) -- trigger
        assert.truthy(audio.tone1.length_counter.channel_enabled)
      end)
      it("triggers on NR14 set length to 64 if it was previously 0", function()
        audio.tone1.length_counter.counter = 0
        io.write_logic[ports.NR14](0x80) -- trigger
        assert.same(audio.tone1.length_counter.counter, 64)
      end)
      it("writes to NR12 set the starting volume on the next trigger", function()
        audio.tone2.volume_envelope:setVolume(0)
        io.write_logic[ports.NR12](0x70)
        io.write_logic[ports.NR14](0x80) -- trigger a new note
        assert.are_same(0x7, audio.tone1.volume_envelope:volume())
      end)
      it("writes to NR12 set the volume adjustment on trigger", function()
        audio.tone1.volume_envelope:setAdjustment(0)
        io.write_logic[ports.NR12](0x08)
        io.write_logic[ports.NR14](0x80) -- trigger a new note
        assert.are_same(1, audio.tone1.volume_envelope:adjustment())
        io.write_logic[ports.NR12](0x00)
        io.write_logic[ports.NR14](0x80) -- trigger a new note
        assert.are_same(-1, audio.tone1.volume_envelope:adjustment())
      end)
      it("writes to NR12 set the volume envelope period", function()
        audio.tone1.volume_envelope.timer:setPeriod(0)
        io.write_logic[ports.NR12](0x07)
        io.write_logic[ports.NR14](0x80) -- trigger a new note
        assert.are_same(7, audio.tone1.volume_envelope.timer:period())
      end)
      it("GB quirk: writes to NR12 treat a period of 0 as 8 instead", function()
        audio.tone1.volume_envelope.timer:setPeriod(0)
        io.write_logic[ports.NR12](0x00)
        io.write_logic[ports.NR14](0x80) -- trigger a new note
        assert.are_same(8, audio.tone1.volume_envelope.timer:period())
      end)
    end)
        describe("Tone 2", function()
      it("trigger writes to NR24 use the low bits from NR23 for the period", function()
        -- Make sure writes to each of the low / high byte use the value from the other half:
        audio.tone2.generator.timer:setPeriod(0)
        io.write_logic[ports.NR23](0x22)
        io.write_logic[ports.NR24](0x81)
        assert.are_same((2048 - 0x0122) * 4, audio.tone2.generator.timer:period())
      end)
      it("writes to NR23 update the period immediately", function()
        audio.tone2.generator.timer:setPeriod(0)
        io.write_logic[ports.NR23](0x44)
        assert.are_same((2048 - 0x0044) * 4, audio.tone2.generator.timer:period())
      end)
      it("non-triggered writes to NR24 still update the period", function()
        audio.tone2.generator.timer:setPeriod(0)
        io.write_logic[ports.NR24](0x03)
        assert.are_same((2048 - 0x0300) * 4, audio.tone2.generator.timer:period())
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
      it("writes to NR21 reload the length counter with (64-L)", function()
        audio.tone2.length_counter.counter = 0
        io.write_logic[ports.NR21](0x3F)
        assert.are_same(audio.tone2.length_counter.counter, 1)
        io.write_logic[ports.NR21](0x00)
        assert.are_same(audio.tone2.length_counter.counter, 64)
      end)
      it("writes to NR24 enable / disable the length counter", function()
        io.write_logic[ports.NR24](0x40)
        assert.truthy(audio.tone2.length_counter.length_enabled)
        io.write_logic[ports.NR24](0x00)
        assert.falsy(audio.tone2.length_counter.length_enabled)
      end)
      it("triggers on NR24 enable the channel", function()
        audio.tone2.length_counter.channel_enabled = false
        io.write_logic[ports.NR24](0x80) -- trigger
        assert.truthy(audio.tone2.length_counter.channel_enabled)
      end)
      it("triggers on NR24 set length to 64 if it was previously 0", function()
        audio.tone2.length_counter.counter = 0
        io.write_logic[ports.NR24](0x80) -- trigger
        assert.same(audio.tone2.length_counter.counter, 64)
      end)
      it("writes to NR22 set the starting volume on the next trigger", function()
        audio.tone2.volume_envelope:setVolume(0)
        io.write_logic[ports.NR22](0x70)
        io.write_logic[ports.NR24](0x80) -- trigger a new note
        assert.are_same(0x7, audio.tone2.volume_envelope:volume())
      end)
      it("writes to NR22 set the volume adjustment on trigger", function()
        audio.tone2.volume_envelope:setAdjustment(0)
        io.write_logic[ports.NR22](0x08)
        io.write_logic[ports.NR24](0x80) -- trigger a new note
        assert.are_same(1, audio.tone2.volume_envelope:adjustment())
        io.write_logic[ports.NR22](0x00)
        io.write_logic[ports.NR24](0x80) -- trigger a new note
        assert.are_same(-1, audio.tone2.volume_envelope:adjustment())
      end)
      it("writes to NR22 set the volume envelope period", function()
        audio.tone2.volume_envelope.timer:setPeriod(0)
        io.write_logic[ports.NR22](0x07)
        io.write_logic[ports.NR24](0x80) -- trigger a new note
        assert.are_same(7, audio.tone2.volume_envelope.timer:period())
      end)
      it("GB quirk: writes to NR22 treat a period of 0 as 8 instead", function()
        audio.tone2.volume_envelope.timer:setPeriod(0)
        io.write_logic[ports.NR22](0x00)
        io.write_logic[ports.NR24](0x80) -- trigger a new note
        assert.are_same(8, audio.tone2.volume_envelope.timer:period())
      end)
    end)
  end)
end)