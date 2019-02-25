local bit32 = require("bit")
local DividingTimer = require("gameboy/audio/dividing_timer")

local SquareWaveGenerator = {}

function SquareWaveGenerator:new(o)
   o = o or {
    frequency_shadow=0,
    sweep_shift=0,
    sweep_negate=false,
    channel_enabled=true,
    waveform=0x0F,
     _pos=0
   }
   o.timer = DividingTimer:new()
   o.timer:onReset(function() o:clock() end)
   o.sweep_timer = DividingTimer:new()
   o.sweep_timer:onReset(function() o:sweep() end)
   setmetatable(o, self)
   self.__index = self
   return o
end

function SquareWaveGenerator:output()
  if self.channel_enabled then
    local rotated_waveform = bit32.bor(bit32.rshift(self.waveform, self._pos), bit32.band(bit32.lshift(self.waveform, 7 - (self._pos)), 0xFE))
    return bit32.band(rotated_waveform, 0x1)
  else
    return 0
  end
end

function SquareWaveGenerator:clock()
  self._pos = self._pos + 1
  if self._pos >= 8 then
    self._pos = 0
  end
end

function SquareWaveGenerator:_next_sweep()
  local sweep_adjustment = bit32.rshift(self.frequency_shadow, self.sweep_shift)
  if self.sweep_negate then
    sweep_adjustment = bit32.bnot(sweep_adjustment)
  end
  return self.frequency_shadow + sweep_adjustment
end

function SquareWaveGenerator:sweep()
  if self.sweep_shift ~= 0 and self.sweep_timer:period() ~= 0 then
    local next_sweep = self:_next_sweep()
    if next_sweep >= 0 then
      -- first adjustment check
      if next_sweep > 2047 then
        self.channel_enabled = false
      else
        self.frequency_shadow = next_sweep
        self.timer:setPeriod((2048 - next_sweep) * 4)
        -- second adjustment check
        next_sweep = self:_next_sweep()
        if next_sweep > 2047 then
          self.channel_enabled = false
        end
      end
    end
  end
end

return SquareWaveGenerator