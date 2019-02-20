local bit32 = require("bit")
local DividingTimer = require("gameboy/audio/dividing_timer")

local WaveSampler = {}

function WaveSampler:new(o)
   o = o or {
    position=0,
    volume_shift=0,
    current_sample=0,
   }
   o.timer = DividingTimer:new()
   o.timer:onReset(function() o:clock() end)
   setmetatable(o, self)
   self.__index = self
   return o
end

function WaveSampler:onRead(callback)
  self._read_byte = callback
end

function WaveSampler:clock()
  self.position = self.position + 1
  if self.position > 31 then
    self.position = 0
  end
  local sample_byte = self._read_byte(bit32.rshift(self.position, 1))
  if self.position % 2 == 0 then
    sample_byte = bit32.rshift(sample_byte, 4)
  end
  self.current_sample = bit32.band(sample_byte, 0xF)
end

function WaveSampler:output()
  return bit32.rshift(self.current_sample, self.volume_shift)
end

return WaveSampler