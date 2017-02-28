local bit32 = require("bit")

local Timers = {}

function Timers.new(modules)
  local io = modules.io
  local interrupts = modules.interrupts

  local timers = {}

  local system_clocks_per_second = 4194304

  timers.system_clock = 0

  timers.clock_rates = {}

  timers.set_normal_speed = function()
    timers.clock_rates[0] = math.floor(system_clocks_per_second / 4096)
    timers.clock_rates[1] = math.floor(system_clocks_per_second / 262144)
    timers.clock_rates[2] = math.floor(system_clocks_per_second / 65536)
    timers.clock_rates[3] = math.floor(system_clocks_per_second / 16384)
  end

  timers.set_double_speed = function()
    timers.clock_rates[0] = math.floor(system_clocks_per_second / 4096 / 2)
    timers.clock_rates[1] = math.floor(system_clocks_per_second / 262144 / 2)
    timers.clock_rates[2] = math.floor(system_clocks_per_second / 65536 / 2)
    timers.clock_rates[3] = math.floor(system_clocks_per_second / 16384 / 2)
  end

  timers.div_base = 0
  timers.timer_offset = 0
  timers.timer_enabled = false

  --local timer_enabled = function()
    --return bit32.band(io.ram[io.ports.TAC], 0x4) == 0x4
  --end

  io.write_logic[io.ports.DIV] = function(byte)
    -- Reset the DIV timer, in this case by re-basing it to the
    -- current system clock, which will roll it back to 0 on this cycle
    div_base = timers.system_clock
  end

  io.read_logic[io.ports.DIV] = function()
    return bit32.band(bit32.rshift(timers.system_clock - timers.div_base, 8), 0xFF)
  end

  io.write_logic[io.ports.TAC] = function(byte)
    io.ram[io.ports.TAC] = byte
    timers.timer_enabled = (bit32.band(io.ram[io.ports.TAC], 0x4) == 0x4)
    timers.timer_offset = timers.system_clock
  end

  timers.update = function()
    if timers.timer_enabled then
      local rate_select = bit32.band(io.ram[io.ports.TAC], 0x3)
      while timers.system_clock > timers.timer_offset + timers.clock_rates[rate_select] do
        io.ram[io.ports.TIMA] = bit32.band(io.ram[io.ports.TIMA] + 1, 0xFF)
        timers.timer_offset = timers.timer_offset + timers.clock_rates[rate_select]
        if io.ram[io.ports.TIMA] == 0x00 then
          --overflow happened, first reset TIMA to TMA
          io.ram[io.ports.TIMA] = io.ram[io.ports.TMA]
          --then, fire off the timer interrupt
          request_interrupt(interrupts.Timer)
        end
      end
    end
  end

  timers.reset = function()
    timers.system_clock = 0
    timers.div_offset = 0
    timers.timer_offset = 0
  end

  timers.save_state = function()
    return {system_clock = timers.system_clock, div_offset = timers.div_offset, timer_offset = timers.timer_offset}
  end

  timers.load_state = function(state)
    timers.system_clock = state.system_clock
    timers.div_offset = state.div_offset
    timers.timer_offset = state.timer_offset
  end

  return timers
end

return Timers
