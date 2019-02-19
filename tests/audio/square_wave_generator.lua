describe("Audio", function()  
  describe("SquareWaveGenerator", function()
    setup(function()
      SquareWaveGenerator = require("gameboy/audio/square_wave_generator")
      bit32 = require("bit")
    end)
    before_each(function() 
      square = SquareWaveGenerator:new()
    end)
    it("can be created", function()
      assert.are_not_same(square, nil)
    end)
    it("clocks adjust the waveform phase 1 bit at a time", function()
      local test_waveform = 0x2D
      square.waveform = test_waveform -- 00101101
      for i = 1, 8 do
        assert.are_same(square:output(), bit32.band(test_waveform, 0x1))
        square:clock()
        test_waveform = bit32.rshift(test_waveform, 1)
      end
    end)
    it("the waveform is clocked when the timer expires", function()
      square.waveform = 0x01
      assert.are_same(square:output(), 1)
      square.timer:reload(10)
      square.timer:advance(10)
      assert.are_same(square:output(), 0)
    end)
    it("sweep clocks adjust the period", function()
      square.frequency_shadow = 500
      square.sweep_timer:setPeriod(1)
      square.sweep_shift = 1
      square.sweep_negate = false
      square:sweep()
      assert.same(square.frequency_shadow, bit32.rshift(500, 1) + 500)
    end)
    it("sweep negate adjusts period downwards", function()
      square.frequency_shadow = 500
      square.sweep_timer:setPeriod(1)
      square.sweep_shift = 1
      square.sweep_negate = true
      square:sweep()
      assert.same(square.frequency_shadow, bit32.bnot(bit32.rshift(500, 1)) + 500)
    end)
    it("sweep silences the channel on overflow", function()
      -- setup tone1 to play a 1 no matter what
      square.waveform = 0xFF -- 00101101
      -- have the sweep register exceed 2047
      square.frequency_shadow = 2040
      square.sweep_shift = 0
      square.sweep_negate = false
      square:sweep()
      -- output should now be 0, indicating the channel has disabled itself
      assert.same(square:output(), 0)
    end)
  end)
end)