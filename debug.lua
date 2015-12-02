dofile("/gameboy/z80.lua")
dofile("/gameboy/rom_header.lua")
dofile("/gameboy/graphics.lua")
dofile("/gameboy/input.lua")

args = {...}

filename = args[1]
file = fs.open("/gameboy/games/"..filename, "rb")
if file then
  print("Reading cartridge into memory...")
  cart_data = read_file_into_byte_array(file)
  print("Read " .. math.ceil(#cart_data / 1024) .. " kB")
  print_cartridge_header(cart_data)
else
  print("Couldn't open ", filename, " bailing.")
  return
end

write("Initializing main memory...")
initialize_memory()
print("Done!")

initialize_graphics()

write("Copying cart data into lower 0x7FFF of main memory...")
for i = 0, 0x7FFF do
  memory[i] = cart_data[i]
end
print("Done!")

function print_register_values()
  local c = reg.flags.c == 1 and "c" or " "
  local n = reg.flags.n == 1 and "n" or " "
  local h = reg.flags.h == 1 and "h" or " "
  local z = reg.flags.z == 1 and "z" or " "
  write(string.format("AF: 0x%02X 0x%02X - ", reg.a, reg.f()))
  print(string.format("BC: 0x%02X 0x%02X  ", reg.b, reg.c))
  write(string.format("DE: 0x%02X 0x%02X - ", reg.d, reg.e))
  print(string.format("HL: 0x%02X 0x%02X", reg.h, reg.l))
  write(string.format("[%s %s %s %s]   ", c, n, h, z))
  print(string.format("(HL): 0x%02X", read_byte(reg.hl())))
  write(string.format("PC: 0x%04X  (PC): 0x%02X  ", reg.pc, read_byte(reg.pc)))
  write(string.format("NN: 0x%02X 0x%02X ", read_byte(reg.pc + 1), read_byte(reg.pc + 2)))
  write(string.format("(0x%02X 0x%02X)", read_byte(reg.pc + 3), read_byte(reg.pc + 4)))
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

print("Press [Enter] to begin execution.")
read()

function run_one_opcode()
  update_graphics()
  update_input()
  return process_instruction()
end

term.clear()
term.setCursorPos(1,1)
print_register_values()
char = ""
while char ~= "q" do
  event, char = os.pullEvent("char")
  if char == " " then
    run_one_opcode()
    term.clear()
    term.setCursorPos(1,1)
    print_register_values()
  end
  if char == "k" then
    for i = 1, 1000 do
      process_instruction()
      update_graphics()
    end
    term.clear()
    term.setCursorPos(1,1)
    print_register_values()
  end
  if char == "r" then
    count = 0
    while run_one_opcode() do
      count = count + 1
      if count >= 20000 then
        term.clear()
        term.setCursorPos(1,1)
        print_register_values()
        --draw_tiles()
        draw_background()
        os.sleep(0)
        count = 0
      end
    end
    term.clear()
    term.setCursorPos(1,1)
    print_register_values()
  end
  if char == "h" then
    old_scanline = scanline()
    while old_scanline == scanline() do
      run_one_opcode()
    end
    term.clear()
    term.setCursorPos(1,1)
    print_register_values()
  end
  if char == "v" then
    while scanline() == 144 do
      run_one_opcode()
    end
    while scanline() ~= 144 do
      run_one_opcode()
    end
    term.clear()
    term.setCursorPos(1,1)
    print_register_values()
    draw_tiles()
  end
  if char == "t" then
    draw_tiles()
    print("Drew Tiles")
  end
  if char == "b" then
    draw_background()
    print("Drew Main BG")
  end
  if char == "w" then
    draw_window()
    print("Drew Window")
  end
  if char == "s" then
    draw_sprites()
    print("Drew Sprites")
  end
  if char == "d" then
    debug_draw_screen()
    print("Drew entire screen!")
  end
end
