local SquareWaveGenerator = {}

function SquareWaveGenerator:new(o)
   o = o or {_waveform=0}
   setmetatable(o, self)
   self.__index = self
   return o
end

function SquareWaveGenerator:waveform()
  return self._waveform
end

function SquareWaveGenerator:setWaveform(waveform)
  self._waveform = waveform
end

return SquareWaveGenerator