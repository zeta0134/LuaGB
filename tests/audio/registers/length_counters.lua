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
    describe("Tone1 - Length Counters - ", function()
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
    end)
    describe("Tone2 - Length Counters - ", function()
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
    end)
    describe("Wave3 - Length Counters - ", function()
      it("writes to NR31 reload the length counter with (256-L)", function()
        audio.wave3.length_counter.counter = 0
        io.write_logic[ports.NR31](0xFF)
        assert.are_same(audio.wave3.length_counter.counter, 1)
        io.write_logic[ports.NR31](0x00)
        assert.are_same(audio.wave3.length_counter.counter, 256)
      end)
      it("writes to NR34 enable / disable the length counter", function()
        io.write_logic[ports.NR34](0x40)
        assert.truthy(audio.wave3.length_counter.length_enabled)
        io.write_logic[ports.NR34](0x00)
        assert.falsy(audio.wave3.length_counter.length_enabled)
      end)
      it("triggers on NR34 enable the channel", function()
        audio.wave3.length_counter.channel_enabled = false
        io.write_logic[ports.NR34](0x80) -- trigger
        assert.truthy(audio.wave3.length_counter.channel_enabled)
      end)
      it("triggers on NR34 set length to 256 if it was previously 0", function()
        audio.wave3.length_counter.counter = 0
        io.write_logic[ports.NR34](0x80) -- trigger
        assert.same(audio.wave3.length_counter.counter, 256)
      end)
    end)
    describe("Noise4 - Length Counters - ", function()
      it("writes to NR41 reload the length counter with (64-L)", function()
        audio.noise4.length_counter.counter = 0
        io.write_logic[ports.NR41](0x3F)
        assert.are_same(audio.noise4.length_counter.counter, 1)
        io.write_logic[ports.NR41](0x00)
        assert.are_same(audio.noise4.length_counter.counter, 64)
      end)
      it("writes to NR44 enable / disable the length counter", function()
        io.write_logic[ports.NR44](0x40)
        assert.truthy(audio.noise4.length_counter.length_enabled)
        io.write_logic[ports.NR44](0x00)
        assert.falsy(audio.noise4.length_counter.length_enabled)
      end)
      it("triggers on NR44 enable the channel", function()
        audio.noise4.length_counter.channel_enabled = false
        io.write_logic[ports.NR44](0x80) -- trigger
        assert.truthy(audio.noise4.length_counter.channel_enabled)
      end)
      it("triggers on NR44 set length to 64 if it was previously 0", function()
        audio.noise4.length_counter.counter = 0
        io.write_logic[ports.NR44](0x80) -- trigger
        assert.same(audio.noise4.length_counter.counter, 64)
      end)
    end)
  end)
end)
