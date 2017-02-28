local Interrupts = {}

function Interrupts.new()
  local interrupts = {}
  interrupts.VBlank = 0x1
  interrupts.LCDStat = 0x2
  interrupts.Timer = 0x4
  interrupts.Serial = 0x8
  interrupts.Joypad = 0x16

  interrupts.enabled = 1

  interrupts.enable = function()
    interrupts.enabled = 1
  end

  interrupts.disable = function()
    interrupts.enabled = 0
  end

  return interrupts
end

return Interrupts
