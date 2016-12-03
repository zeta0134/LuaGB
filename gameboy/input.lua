memory = require("gameboy/memory")

GbKeys = {}
GbKeys.Left = 0
GbKeys.Right = 0
GbKeys.Up = 0
GbKeys.Down = 0
GbKeys.A = 0
GbKeys.B = 0
GbKeys.Start = 0
GbKeys.Select = 0

function update_input()
  d_pad_bits = GbKeys.Right + bit32.lshift(GbKeys.Left, 1) + bit32.lshift(GbKeys.Up, 2) + bit32.lshift(GbKeys.Down, 3)
  button_bits = GbKeys.A + bit32.lshift(GbKeys.B, 1) + bit32.lshift(GbKeys.Select, 2) + bit32.lshift(GbKeys.Start, 3)

  active_bits = 0
  if bit32.band(memory[0xFF00], 0x20) == 0 then
    active_bits = bit32.bor(active_bits, button_bits)
  end
  if bit32.band(memory[0xFF00], 0x10) == 0 then
    active_bits = bit32.bor(active_bits, d_pad_bits)
  end
  active_bits = bit32.bnot(active_bits)


  memory[0xFF00] = bit32.bor(memory[0xFF00], bit32.band(active_bits, 0x0F))
end
