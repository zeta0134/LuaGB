local bit32 = require("bit")
local DividingTimer = require("gameboy/audio/dividing_timer")

local WaveSampler = {}

function WaveSampler:new(o)
   o = o or {
    position=0,
    volume_sweep=0,
    current_sample=false
   }
   o.timer = DividingTimer:new()
   o.timer:onReset(function() o:clock() end)
   setmetatable(o, self)
   self.__index = self
   return o
end

return WaveSampler