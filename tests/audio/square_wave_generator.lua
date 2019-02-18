describe("Audio", function()  
  describe("SquareWaveGenerator", function()
    setup(function()
      SquareWaveGenerator = require("gameboy/audio/square_wave_generator")
      bit32 = require("bit")
    end)
    it("can be created", function()
      square = SquareWaveGenerator:new()
      assert.are_not_same(square, nil)
    end)
    it("waveform can be set", function()
      local square = SquareWaveGenerator:new()
      square:setWaveform(0x0F)
      assert.are_same(square:waveform(), 0x0F)
    end)
    it("clocks adjust the waveform phase 1 bit at a time", function()
      local square = SquareWaveGenerator:new()
      local test_waveform = 0x2D
      square:setWaveform(test_waveform) -- 00101101
      for i = 1, 8 do
        assert.are_same(square:output(), bit32.band(test_waveform, 0x1))
        square:clock()
        test_waveform = bit32.rshift(test_waveform, 1)
      end
    end)
    it("the waveform is clocked when the timer expires", function()
      local square = SquareWaveGenerator:new()
      square:setWaveform(0x01)
      assert.are_same(square:output(), 1)
      square.timer:reload(10)
      square.timer:advance(10)
      assert.are_same(square:output(), 0)
    end)
  end)
end)