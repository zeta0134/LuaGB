local timers = {}

local system_clocks_per_second = 4398046

timers.clock_rates = {}
timers.clock_rates[0] = math.floor(system_clocks_per_second / 4096)
timers.clock_rates[1] = math.floor(system_clocks_per_second / 262144)
timers.clock_rates[2] = math.floor(system_clocks_per_second / 65536)
timers.clock_rates[3] = math.floor(system_clocks_per_second / 16384)

timers.div_offset = 0
timers.timer_offset = 0

local timer_enabled = function()
  return bit32.band(io.ram[0x07], 0x4) == 0x4
end

timers.update = function()
  -- DIV
  if clock > timers.div_offset + 256 then
    io.ram[0x04] = bit32.band(io.ram[0x04] + 1, 0xFF)
    timers.div_offset = timers.div_offset + 256
  end

  if timer_enabled() then
    local rate_select = bit32.band(io.ram[0x07], 0x3)
    if clock > timers.timer_offset + timers.clock_rates[rate_select] then
      io.ram[0x5] = bit32.band(io.ram[0x05] + 1, 0xFF)
      timers.timer_offset = timers.timer_offset + timers.clock_rates[rate_select]
      if io.ram[0x05] == 0x00 then
        --overflow happened, first reset TIMA to TMA
        io.ram[0x05] = io.ram[0x06]
        --then, fire off the timer interrupt
        request_interrupt(Interrupt.Timer)
      end
    end
  end
end

return timers
