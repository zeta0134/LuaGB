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

return FrameSequencer