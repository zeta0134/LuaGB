local LengthCounter = {}

function LengthCounter:new(o)
   o = o or {counter=0,length_enabled=false,channel_enabled=true}
   setmetatable(o, self)
   self.__index = self
   return o
end

function LengthCounter:clock()
  if self.length_enabled then
    self.counter = self.counter - 1
  end
end

return LengthCounter
