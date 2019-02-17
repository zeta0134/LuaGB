local bit32 = require("bit")
local DividingTimer = require("gameboy/audio/dividing_timer")

local SquareWaveGenerator = {}

function SquareWaveGenerator:new(o)
   o = o or {_waveform=0}
   o.timer = DividingTimer:new()
   o.timer:onReset(function() o:clock() end)
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

function SquareWaveGenerator:clock()
  self._waveform = bit32.bor(bit32.rshift(self._waveform, 1), bit32.band(bit32.lshift(self._waveform, 7), 0xFE))
end

return SquareWaveGenerator