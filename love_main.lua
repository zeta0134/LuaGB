bit32 = require("bit")

require("gameboy/z80")
require("gameboy/graphics")
require("gameboy/rom_header")
require("gameboy/input")

function love.load(args)
  local game_name = args[2]

  file_data, size = love.filesystem.read("games/"..game_name)
  if file_data then
    print("Reading cartridge into memory...")
    cart_data = {}
    for i = 0, size - 1 do
      cart_data[i] = file_data:byte(i + 1)
    end
    print("Read " .. math.ceil(#cart_data / 1024) .. " kB")
    print_cartridge_header(cart_data)
  else
    print("Couldn't open ", game_name, " bailing.")
    return
  end

  print("Initializing main memory...")
  initialize_memory()
  print("Done!")

  print("Initializing graphics...")
  initialize_graphics()
  print("Done!")

  -- TODO: Not this please.
  print("Copying cart data into lower 0x7FFF of main memory...")
  for i = 0, 0x7FFF do
    memory[i] = cart_data[i]
  end
  print("Done!")
end

function print_register_values()
  local c = reg.flags.c == 1 and "c" or " "
  local n = reg.flags.n == 1 and "n" or " "
  local h = reg.flags.h == 1 and "h" or " "
  local z = reg.flags.z == 1 and "z" or " "
  io.write(string.format("AF: 0x%02X 0x%02X - ", reg.a, reg.f()))
  print(string.format("BC: 0x%02X 0x%02X  ", reg.b, reg.c))
  io.write(string.format("DE: 0x%02X 0x%02X - ", reg.d, reg.e))
  print(string.format("HL: 0x%02X 0x%02X", reg.h, reg.l))
  io.write(string.format("[%s %s %s %s]   ", c, n, h, z))
  print(string.format("(HL): 0x%02X", read_byte(reg.hl())))
  io.write(string.format("PC: 0x%04X  (PC): 0x%02X  ", reg.pc, read_byte(reg.pc)))
  io.write(string.format("NN: 0x%02X 0x%02X ", read_byte(reg.pc + 1), read_byte(reg.pc + 2)))
  io.write(string.format("(0x%02X 0x%02X)", read_byte(reg.pc + 3), read_byte(reg.pc + 4)))
  print(string.format("SP: 0x%04X  (SP): 0x%02X 0x%02X %d %d", reg.sp, read_byte(reg.sp), read_byte(reg.sp + 1), read_byte(reg.sp), read_byte(reg.sp + 1)))
  print(string.format("Clock: %d", clock))
  print(string.format("GPU: Mode: %d Scanline: %d", Status.Mode(), scanline()))
  print(string.format("Halted: %d  IME: %d  IE: 0x%04X  IF: 0x%04X", halted, interrupts_enabled, read_byte(0xFFFF), read_byte(0xFF0F)))
  print("[Space] = Step | [K] = Run 1000")
  print("[R] = Run Until Error or Breakpoint")
  print("[V] = Run Until VBlank")
  print("[H] = Run until HBlank")
  print("Draw: [T] Tiles, [B] = BG, [W] = Window, [S] = Sprites, [D] = Entire Screen")
end

function run_one_opcode()
  update_graphics()
  update_input()
  return process_instruction()
end

function love.textinput(char)
  if char == " " then
    run_one_opcode()
    print_register_values()
  end
end

function love.draw()
    love.graphics.print(reg.a, 400, 300)
end
