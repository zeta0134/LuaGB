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
  end)
end)