local bit32 = require("bit")
local DividingTimer = require("gameboy/audio/dividing_timer")

local LinearFeedbackShiftRegister = {}

function LinearFeedbackShiftRegister:new(o)
   o = o or {
    current_value=0,
    width_mode=0,
   }
   o.timer = DividingTimer:new()
   o.timer:onReset(function() o:clock() end)
   setmetatable(o, self)
   self.__index = self
   return o
end

return LinearFeedbackShiftRegister