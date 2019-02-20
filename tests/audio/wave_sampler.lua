describe("Audio", function()  
  describe("WaveSampler", function()
    setup(function()
      WaveSampler = require("gameboy/audio/wave_sampler")
      bit32 = require("bit")
    end)
    before_each(function() 
      wave_sampler = WaveSampler:new()
    end)
    it("can be created", function()
      assert.are_not_same(wave_sampler, nil)
    end)
    it("onRead pulls the current 4-bit nybble from the sample buffer when clocked", function()
      local sample_buffer = {0x01, 0x23, 0x45, 0x67};
      local expected_nybbles = {0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7};
      wave_sampler:onRead(function(a) return sample_buffer[a + 1] end)
      -- start at the end, to test wrap-around behavior
      wave_sampler.position = 31
      for i = 1, 8 do        
        wave_sampler:clock()
        assert.same(wave_sampler.current_sample, expected_nybbles[i])
      end
    end)
    it("volume shifts the current sample accordingly", function()
      wave_sampler.current_sample = 0xF
      for i = 0, 3 do
        wave_sampler.volume_shift = i
        assert.same(wave_sampler:output(), bit32.rshift(0xF, i))
      end
    end)
  end)
end)