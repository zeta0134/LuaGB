local DividingTimer = {}

function DividingTimer:new(o)
   o = o or {_period=0,_counter=0}
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

function DividingTimer:reload(optLength)
  if optLength then
    self._period = optLength
    self._counter = optLength
  else
    self._counter = self._period
  end
end

function DividingTimer:remainingClocks()
  return self._counter
end

function DividingTimer:clock()
  self:advance(1)
end

function DividingTimer:advance(clocks)
  self._counter = self._counter - clocks
  while self._counter <= 0 do
    self._counter = self._counter + self._period
  end
end

return DividingTimer