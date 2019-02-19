local LengthCounter = {}

function LengthCounter:new(o)
   o = o or {counter=0,length_enabled=false,channel_enabled=true}
   setmetatable(o, self)
   self.__index = self
   return o
end

function LengthCounter:clock()
  if self.length_enabled and self.counter ~= 0 then
    self.counter = self.counter - 1
    if self.counter == 0 then
      self.channel_enabled = false
    end
  end
end

function LengthCounter:output(input)
  if self.channel_enabled then
    return input
  else
    return 0
  end
end

return LengthCounter
