local bit32 = require("bit")
local DividingTimer = require("gameboy/audio/dividing_timer")

local LinearFeedbackShiftRegister = {}

function LinearFeedbackShiftRegister:new(o)
   o = o or {
    current_value=0,
    width_mode=0,
   }
   o.timer = DividingTimer:new()
   o.timer:onReset(function() o:clock() end)
   setmetatable(o, self)
   self.__index = self
   return o
end

function LinearFeedbackShiftRegister:clock()
  local shift_result = bit32.rshift(self.current_value, 1)
  local xor_result = bit32.band(bit32.bxor(shift_result, self.current_value), 0x1)
  local lfsr_result = bit32.lshift(xor_result, 14) + shift_result
  if self.width_mode == 1 then

    lfsr_result = bit32.bor(bit32.band(0x7FBF, lfsr_result), bit32.lshift(xor_result, 6))
  end
  self.current_value = lfsr_result
end

function LinearFeedbackShiftRegister:reset()
  self.current_value = 0x7FFF
end

local divisor_table = {
  [0]=8,
  [1]=16,
  [2]=32,
  [3]=48,
  [4]=64,
  [5]=80,
  [6]=96,
  [7]=112,
}

function LinearFeedbackShiftRegister:setPeriod(divisor_code, shift_amount)
  local period = bit32.lshift(divisor_table[divisor_code], shift_amount)
  self.timer.period = period
end

function LinearFeedbackShiftRegister:output()
  return bit32.band(self.current_value, 0x1)
end

return LinearFeedbackShiftRegister