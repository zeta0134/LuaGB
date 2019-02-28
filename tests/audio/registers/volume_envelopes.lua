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
    describe("Tone1 - Volume Envelope - ", function()
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
        audio.tone1.volume_envelope.timer.period = 0
        io.write_logic[ports.NR12](0x07)
        io.write_logic[ports.NR14](0x80) -- trigger a new note
        assert.are_same(7, audio.tone1.volume_envelope.timer.period)
      end)
      it("GB quirk: writes to NR12 treat a period of 0 as 8 instead", function()
        audio.tone1.volume_envelope.timer.period = 0
        io.write_logic[ports.NR12](0x00)
        io.write_logic[ports.NR14](0x80) -- trigger a new note
        assert.are_same(8, audio.tone1.volume_envelope.timer.period)
      end)
    end)
    describe("Tone2 - Volume Envelope - ", function()
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
        audio.tone2.volume_envelope.timer.period = 0
        io.write_logic[ports.NR22](0x07)
        io.write_logic[ports.NR24](0x80) -- trigger a new note
        assert.are_same(7, audio.tone2.volume_envelope.timer.period)
      end)
      it("GB quirk: writes to NR22 treat a period of 0 as 8 instead", function()
        audio.tone2.volume_envelope.timer.period = 0
        io.write_logic[ports.NR22](0x00)
        io.write_logic[ports.NR24](0x80) -- trigger a new note
        assert.are_same(8, audio.tone2.volume_envelope.timer.period)
      end)
    end)
    describe("Noise4 - Volume Envelope - ", function()
      it("writes to NR42 set the starting volume on the next trigger", function()
        audio.noise4.volume_envelope:setVolume(0)
        io.write_logic[ports.NR42](0x70)
        io.write_logic[ports.NR44](0x80) -- trigger a new note
        assert.are_same(0x7, audio.noise4.volume_envelope:volume())
      end)
      it("writes to NR42 set the volume adjustment on trigger", function()
        audio.noise4.volume_envelope:setAdjustment(0)
        io.write_logic[ports.NR42](0x08)
        io.write_logic[ports.NR44](0x80) -- trigger a new note
        assert.are_same(1, audio.noise4.volume_envelope:adjustment())
        io.write_logic[ports.NR42](0x00)
        io.write_logic[ports.NR44](0x80) -- trigger a new note
        assert.are_same(-1, audio.noise4.volume_envelope:adjustment())
      end)
      it("writes to NR42 set the volume envelope period", function()
        audio.noise4.volume_envelope.timer.period = 0
        io.write_logic[ports.NR42](0x07)
        io.write_logic[ports.NR44](0x80) -- trigger a new note
        assert.are_same(7, audio.noise4.volume_envelope.timer.period)
      end)
      it("GB quirk: writes to NR42 treat a period of 0 as 8 instead", function()
        audio.noise4.volume_envelope.timer.period = 0
        io.write_logic[ports.NR42](0x00)
        io.write_logic[ports.NR44](0x80) -- trigger a new note
        assert.are_same(8, audio.noise4.volume_envelope.timer.period)
      end)
    end)
  end)
end)