local DividingTimer = require("gameboy/audio/dividing_timer")

local VolumeEnvelope = {}

function VolumeEnvelope:new(o)
   o = o or {_volume,_adjustment}
   o.timer = DividingTimer:new()
   o.timer:onReset(function() o:clock() end)
   setmetatable(o, self)
   self.__index = self
   return o
end

return VolumeEnvelope