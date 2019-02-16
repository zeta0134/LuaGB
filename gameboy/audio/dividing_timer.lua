local DividingTimer = {}

function DividingTimer:new(o)
   o = o or {_period=0}
   setmetatable(o, self)
   self.__index = self
   return o
end

function DividingTimer:setPeriod(clocks)
  self._period = clocks
end

function DividingTimer:period()
  return self._period
end

return DividingTimer