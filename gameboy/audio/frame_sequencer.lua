local DividingTimer = require("gameboy/audio/dividing_timer")

local FrameSequencer = {}

function FrameSequencer:new(o)
   o = o or {step=0}
   o.timer = DividingTimer:new()
   o.timer:onReset(function() o:clock() end)
   setmetatable(o, self)
   self.__index = self
   return o
end

function FrameSequencer:clock()
  if self.step == 0 or self.step == 2 or self.step == 4 or self.step == 6 then
    if self._length_callback then
      self._length_callback()
    end
  end
  if self.step == 7 then
    if self._volume_callback then
      self._volume_callback()
    end
  end
  if self.step == 2 or self.step == 6 then
    if self._sweep_callback then
      self._sweep_callback()
    end
  end
  self.step = self.step + 1
  if self.step >= 8 then
    self.step = 0
  end
end

function FrameSequencer:onLength(callback)
  self._length_callback = callback
end

function FrameSequencer:onVolume(callback)
  self._volume_callback = callback
end

function FrameSequencer:onSweep(callback)
  self._sweep_callback = callback
end

return FrameSequencer