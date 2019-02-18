describe("Audio", function()
  describe("FrameSequencer", function()
    setup(function()
      FrameSequencer = require("gameboy/audio/frame_sequencer")
    end)
    before_each(function()
      frame_sequencer = FrameSequencer:new()
    end)
    it("can be created", function()
      assert.not_same(frame_sequencer, nil)
    end)
    it("step advances through 0-7 when clocked", function()
      for i = 0, 7 do
        assert.same(i, frame_sequencer.step)
        frame_sequencer:clock()
      end
      -- should have wrapped back around to 0
      assert.same(0, frame_sequencer.step)
    end)
    it("length is clocked on steps 0, 2, 4, and 6", function()
      local work = spy.new(function() end)
      frame_sequencer:onLength(work)
      frame_sequencer:clock() -- step 0
      assert.spy(work).was.called()
      work:clear()

      frame_sequencer:clock() -- step 1
      assert.spy(work).was_not.called()
      work:clear()

      frame_sequencer:clock() -- step 2
      assert.spy(work).was.called()
      work:clear()

      frame_sequencer:clock() -- step 3
      assert.spy(work).was_not.called()
      work:clear()

      frame_sequencer:clock() -- step 4
      assert.spy(work).was.called()
      work:clear()

      frame_sequencer:clock() -- step 5
      assert.spy(work).was_not.called()
      work:clear()

      frame_sequencer:clock() -- step 6
      assert.spy(work).was.called()
      work:clear()

      frame_sequencer:clock() -- step 7
      assert.spy(work).was_not.called()
    end)
    it("volume is clocked on step 7", function()
      local work = spy.new(function() end)
      frame_sequencer:onVolume(work)
      frame_sequencer:clock() -- step 0
      frame_sequencer:clock() -- step 1
      frame_sequencer:clock() -- step 2
      frame_sequencer:clock() -- step 3
      frame_sequencer:clock() -- step 4
      frame_sequencer:clock() -- step 5
      frame_sequencer:clock() -- step 6
      assert.spy(work).was_not.called()
      work:clear()
      frame_sequencer:clock() -- step 7
      assert.spy(work).was.called()
      work:clear()
    end)
    it("sweep is clocked on steps 2 and 6", function()
      local work = spy.new(function() end)
      frame_sequencer:onSweep(work)
      frame_sequencer:clock() -- step 0
      frame_sequencer:clock() -- step 1
      assert.spy(work).was_not.called()
      work:clear()
      frame_sequencer:clock() -- step 2
      assert.spy(work).was.called()
      work:clear()
      frame_sequencer:clock() -- step 3
      frame_sequencer:clock() -- step 4
      frame_sequencer:clock() -- step 5
      assert.spy(work).was_not.called()
      work:clear()
      frame_sequencer:clock() -- step 6
      assert.spy(work).was.called()
      work:clear()
      frame_sequencer:clock() -- step 7
      assert.spy(work).was_not.called()
      work:clear()
    end)
  end)
end)