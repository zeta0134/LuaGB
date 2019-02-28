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