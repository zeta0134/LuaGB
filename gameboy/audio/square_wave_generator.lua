local bit32 = require("bit")
local DividingTimer = require("gameboy/audio/dividing_timer")

local SquareWaveGenerator = {}

function SquareWaveGenerator:new(o)
   o = o or {_waveform=0,_pos=0}
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
  local rotated_waveform = bit32.bor(bit32.rshift(self._waveform, self._pos), bit32.band(bit32.lshift(self._waveform, 7 - (self._pos)), 0xFE))
  return bit32.band(rotated_waveform, 0x1)
end

function SquareWaveGenerator:clock()
  self._pos = self._pos + 1
  if self._pos >= 8 then
    self._pos = 0
  end
end

return SquareWaveGenerator