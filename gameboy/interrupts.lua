local bit32 = require("bit")

local Interrupts = {}

function Interrupts.new(modules)
  local interrupts = {}

  local io = modules.io

  interrupts.VBlank = 0x1
  interrupts.LCDStat = 0x2
  interrupts.Timer = 0x4
  interrupts.Serial = 0x8
  interrupts.Joypad = 0x16

  interrupts.enabled = 1

  interrupts.service_handler = function() end

  interrupts.enable = function()
    interrupts.enabled = 1
  end

  interrupts.disable = function()
    interrupts.enabled = 0
  end

  function interrupts.raise(bitmask)
    io.ram[0x0F] = bit32.band(bit32.bor(io.ram[0x0F], bitmask), 0x1F)
    interrupts.service_handler()
  end

  io.write_logic[io.ports.IF] = function(byte)
    io.ram[io.ports.IF] = byte
    if byte ~= 0 then
      interrupts.service_handler()
    end
  end

  io.write_logic[io.ports.IE] = function(byte)
    io.ram[io.ports.IE] = byte
    if byte ~= 0 then
      interrupts.service_handler()
    end
  end

  return interrupts
end

return Interrupts
