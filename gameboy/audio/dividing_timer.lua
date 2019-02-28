local DividingTimer = {}

function DividingTimer:new(o)
   o = o or {period=0,_counter=0}
   setmetatable(o, self)
   self.__index = self
   return o
end

function DividingTimer:reload(optLength)
  if optLength then
    self.period = optLength
    self._counter = optLength
  else
    self._counter = self.period
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
  while self._counter <= 0 and self.period ~= 0 do
    self._counter = self._counter + self.period
    if self._doWork then
      self._doWork()
    end
  end
end

function DividingTimer:onReset(callback)
  self._doWork = callback
end

return DividingTimer