local interrupts = {}
interrupts.VBlank = 0x1
interrupts.LCDStat = 0x2
interrupts.Timer = 0x4
interrupts.Serial = 0x8
interrupts.Joypad = 0x16

return interrupts
