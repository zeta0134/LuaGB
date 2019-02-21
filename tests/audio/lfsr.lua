describe("Audio", function()  
  describe("LinearFeedbackShiftRegister", function()
    setup(function()
      LinearFeedbackShiftRegister = require("gameboy/audio/lsfr")
      bit32 = require("bit")
    end)
    before_each(function() 
      lsfr = LinearFeedbackShiftRegister:new()
      lsfr.width_mode = 0
    end)
    it("When clocked, shifts the register contents to the right", function()
      lsfr.current_value = 0x7423
      lsfr:clock()
      expected = bit32.rshift(0x7423, 1)
      -- note: the 15th bit is not necessarily 0, so we must mask it out
      assert.same(expected, bit32.band(lsfr.current_value, 0x3FFF))
    end)
    it("When clocked, bit 14 is set to the lower two bits XOR'd", function()
      lsfr.current_value = 0x0 -- 00
      lsfr:clock()
      assert.same(0x0000, bit32.band(lsft.current_value, 0x4000))
      lsfr.current_value = 0x1 -- 01
      lsfr:clock()
      assert.same(0x4000, bit32.band(lsft.current_value, 0x4000))
      lsfr.current_value = 0x2 -- 10
      lsfr:clock()
      assert.same(0x4000, bit32.band(lsft.current_value, 0x4000))
      lsfr.current_value = 0x3 -- 11
      lsfr:clock()
      assert.same(0x0000, bit32.band(lsft.current_value, 0x4000))
    end)
    it("When clocked in mode 1, bit 6 is also set to the lower two bits XOR'd", function()
      lsfr.current_value = 0x0 -- 00
      lsfr:clock()
      assert.same(0x0000, bit32.band(lsft.current_value, 0x4040))
      lsfr.current_value = 0x1 -- 01
      lsfr:clock()
      assert.same(0x4040, bit32.band(lsft.current_value, 0x4040))
      lsfr.current_value = 0x2 -- 10
      lsfr:clock()
      assert.same(0x4040, bit32.band(lsft.current_value, 0x4040))
      lsfr.current_value = 0x3 -- 11
      lsfr:clock()
      assert.same(0x0000, bit32.band(lsft.current_value, 0x4040))
    end)
    it("When reset, all bits are set to 1", function()
      lsfr.current_value = 0
      lsfr:reset()
      assert.same(0x7FFF, lsfr.current_value)
    end)
  end)
end)