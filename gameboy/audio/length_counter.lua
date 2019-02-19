local LengthCounter = {}

function LengthCounter:new(o)
   o = o or {counter=0,length_enabled=false,channel_enabled=true}
   setmetatable(o, self)
   self.__index = self
   return o
end

return LengthCounter
