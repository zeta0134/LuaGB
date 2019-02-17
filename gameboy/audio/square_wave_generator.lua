local bit32 = require("bit")

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

function SquareWaveGenerator:output()
  return bit32.band(self._waveform, 0x1)
end

return SquareWaveGenerator