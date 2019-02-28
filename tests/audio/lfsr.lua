describe("Audio", function()  
  describe("LinearFeedbackShiftRegister", function()
    setup(function()
      LinearFeedbackShiftRegister = require("gameboy/audio/lfsr")
      bit32 = require("bit")
    end)
    before_each(function() 
      lfsr = LinearFeedbackShiftRegister:new()
      lfsr.width_mode = 0
    end)
    it("When clocked, shifts the register contents to the right", function()
      lfsr.current_value = 0x7423
      lfsr:clock()
      expected = bit32.rshift(0x7423, 1)
      -- note: the 15th bit is not necessarily 0, so we must mask it out
      assert.same(expected, bit32.band(lfsr.current_value, 0x3FFF))
    end)
    it("When clocked, bit 14 is set to the lower two bits XOR'd", function()
      lfsr.current_value = 0x0 -- 00
      lfsr:clock()
      assert.same(0x0000, bit32.band(lfsr.current_value, 0x4000))
      lfsr.current_value = 0x1 -- 01
      lfsr:clock()
      assert.same(0x4000, bit32.band(lfsr.current_value, 0x4000))
      lfsr.current_value = 0x2 -- 10
      lfsr:clock()
      assert.same(0x4000, bit32.band(lfsr.current_value, 0x4000))
      lfsr.current_value = 0x3 -- 11
      lfsr:clock()
      assert.same(0x0000, bit32.band(lfsr.current_value, 0x4000))
    end)
    it("When clocked in mode 1, bit 6 is also set to the lower two bits XOR'd", function()
      lfsr.width_mode = 1
      lfsr.current_value = 0x0 -- 00
      lfsr:clock()
      assert.same(0x0000, bit32.band(lfsr.current_value, 0x4040))
      lfsr.current_value = 0x1 -- 01
      lfsr:clock()
      assert.same(0x4040, bit32.band(lfsr.current_value, 0x4040))
      lfsr.current_value = 0x2 -- 10
      lfsr:clock()
      assert.same(0x4040, bit32.band(lfsr.current_value, 0x4040))
      lfsr.current_value = 0x3 -- 11
      lfsr:clock()
      assert.same(0x0000, bit32.band(lfsr.current_value, 0x4040))
    end)
    it("When reset, all bits are set to 1", function()
      lfsr.current_value = 0
      lfsr:reset()
      assert.same(0x7FFF, lfsr.current_value)
    end)
    it("Output is based on the low bit of the register", function()
      lfsr.current_value = 0x7FFE
      assert.same(0, lfsr:output())
      lfsr.current_value = 0x0001
      assert.same(1, lfsr:output())
    end)
  end)
end)