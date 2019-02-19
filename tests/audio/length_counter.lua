describe("Audio", function()
  describe("LengthCounter", function()
    setup(function()
      LengthCounter = require("gameboy/audio/length_counter")
    end)
    before_each(function()
      length_counter = LengthCounter:new()
    end)
    it("can be created", function()
      assert.not_same(length_counter, nil)
    end)
    it("decrements counter when clocked while enabled", function()
      length_counter.counter = 2
      length_counter.length_enabled = true
      length_counter:clock()
      assert.same(length_counter.counter, 1)
    end)
    it("does nothing if clocked while disabled", function()
      length_counter.counter = 2
      length_counter.length_enabled = false
      length_counter:clock()
      assert.same(length_counter.counter, 2)
    end)
    it("if counter clocked to 0, disables channel", function()
      length_counter.counter = 1
      length_counter.length_enabled = true
      length_counter.channel_enabled = true
      length_counter:clock()
      assert.same(length_counter.channel_enabled, false)
    end)
    it("output is silenced when the channel is disabled", function()
      length_counter.channel_enabled = true
      assert.same(length_counter.output(1), 1)
      length_counter.channel_enabled = false
      assert.same(length_counter.output(1), 0)
    end)
  end)
end)
