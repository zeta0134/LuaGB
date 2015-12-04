bit32 = require("bit")

require("gameboy/z80")
require("gameboy/graphics")
require("gameboy/rom_header")
require("gameboy/input")

local ubuntu_font

local game_screen_canvas
local debug_tile_canvas

function love.load(args)
  love.window.setMode(1280,800)
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setPointStyle("rough")
  ubuntu_font = love.graphics.newFont("UbuntuMono-R.ttf", 24)
  game_screen_canvas = love.graphics.newCanvas(256, 256)
  debug_tile_canvas = love.graphics.newCanvas(256, 256)

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

  --io.write(string.format("AF: 0x%02X 0x%02X - ", reg.a, reg.f()))
  --print(string.format("BC: 0x%02X 0x%02X  ", reg.b, reg.c))
  --io.write(string.format("DE: 0x%02X 0x%02X - ", reg.d, reg.e))
  --print(string.format("HL: 0x%02X 0x%02X", reg.h, reg.l))

  love.graphics.setColor(255,255,64)
  love.graphics.print(string.format("A: %02X", reg.a), 0, 0)
  love.graphics.setColor(64,128,64)
  love.graphics.print(string.format("F: %02X", reg.f()), 80, 0)
  love.graphics.setColor(108,108,255)
  love.graphics.print(string.format("B: %02X", reg.b), 0, 24)
  love.graphics.setColor(152,80,32)
  love.graphics.print(string.format("C: %02X", reg.c), 80, 24)
  love.graphics.setColor(192,128,64)
  love.graphics.print(string.format("D: %02X", reg.d), 0, 48)
  love.graphics.setColor(64,255,64)
  love.graphics.print(string.format("E: %02X", reg.e), 80, 48)
  love.graphics.setColor(224,196,128)
  love.graphics.print(string.format("H: %02X", reg.h), 0, 72)
  love.graphics.setColor(255,255,255)
  love.graphics.print(string.format("L: %02X", reg.l), 80, 72)

  love.graphics.setColor(192,192,192)
  love.graphics.print(string.format("Flags: [%s %s %s %s])", c, n, h, z), 160, 0)
  love.graphics.setColor(108,108,255)
  love.graphics.print(string.format("BC: %04X (BC): %02X", reg.bc(), read_byte(reg.bc())), 160, 24)
  love.graphics.setColor(192,128,64)
  love.graphics.print(string.format("DE: %04X (DE): %02X", reg.de(), read_byte(reg.de())), 160, 48)
  love.graphics.setColor(224,196,128)
  love.graphics.print(string.format("HL: %04X (HL): %02X", reg.hl(), read_byte(reg.hl())), 160, 72)

  love.graphics.setColor(192, 192, 255)
  love.graphics.print(string.format("SP: %04X (SP): %02X %02X %02X %02X",
                      reg.sp, read_byte(reg.sp), read_byte(reg.sp + 1), read_byte(reg.sp + 2), read_byte(reg.sp + 3)), 0, 120)

  love.graphics.setColor(255, 192, 192)
  love.graphics.print(string.format("PC: %04X (PC): %02X %02X %02X %02X",
                      reg.pc, read_byte(reg.pc), read_byte(reg.pc + 1), read_byte(reg.pc + 2), read_byte(reg.pc + 3)), 0, 144)

  love.graphics.setColor(255, 255, 255)
  love.graphics.print(string.format("Clock: %d", clock), 380, 0)
  love.graphics.print(string.format("GPU: Mode: %d", Status.Mode()), 380, 24)
  love.graphics.print(string.format("Scanline: %d", scanline()), 380, 48)
  love.graphics.print(string.format("Frame: %d", vblank_count), 380, 72)
  love.graphics.print(string.format("Halted: %d  IME: %d  IE: %02X  IF: %02X", halted, interrupts_enabled, read_byte(0xFFFF), read_byte(0xFF0F)), 0, 168)
end

function print_instructions()
  love.graphics.setColor(255, 255, 255)
  love.graphics.print("[Space] = Step | [K] = Run 1000 instructions | [H] = Run until HBlank | [V] = Run until VBlank", 0, 780)
  --print("[Space] = Step | [K] = Run 1000")
  --print("[R] = Run Until Error or Breakpoint")
  --print("[V] = Run Until VBlank")
  --print("[H] = Run until HBlank")
  --print("Draw: [T] Tiles, [B] = BG, [W] = Window, [S] = Sprites, [D] = Entire Screen")
end

function print_io_value(name, address, x, y)
  love.graphics.print(string.format("%04X [%s] %02X", address, name, memory[address]), x, y)
end

function print_io_values()
  love.graphics.setColor(255, 255, 255)
  local x = 850
  local y = 0
  -- joypad
  print_io_value("JOY ", 0xFF00, x, y); y = y + 24
  -- serial transfer cable (unimplemented entirely)
  print_io_value("SB  ", 0xFF01, x, y); y = y + 24
  print_io_value("SC  ", 0xFF02, x, y); y = y + 24
  -- timers
  print_io_value("DIV ", 0xFF04, x, y); y = y + 24
  print_io_value("TIMA", 0xFF05, x, y); y = y + 24
  print_io_value("TMA ", 0xFF06, x, y); y = y + 24
  print_io_value("TAC ", 0xFF07, x, y); y = y + 24
  -- interrupt flags (this holds currently requested interrupts)
  print_io_value("IF  ", 0xFF0F, x, y); y = y + 24

  -- graphics
  print_io_value("LCDC", 0xFF40, x, y); y = y + 24
  print_io_value("STAT", 0xFF41, x, y); y = y + 24
  print_io_value("SCY ", 0xFF42, x, y); y = y + 24
  print_io_value("SCX ", 0xFF43, x, y); y = y + 24
  print_io_value("LY  ", 0xFF44, x, y); y = y + 24
  print_io_value("LYC ", 0xFF45, x, y); y = y + 24
  print_io_value("BGP ", 0xFF47, x, y); y = y + 24
  print_io_value("OBP0", 0xFF48, x, y); y = y + 24
  print_io_value("OBP1", 0xFF49, x, y); y = y + 24
  print_io_value("WY  ", 0xFF4A, x, y); y = y + 24
  print_io_value("WX  ", 0xFF4B, x, y); y = y + 24

  -- Interrupt enable
  print_io_value("IE  ", 0xFFFF, x, y); y = y + 24

  -- sound
  x = 1100
  y = 0
  print_io_value("NR10", 0xFF10, x, y); y = y + 24
  print_io_value("NR11", 0xFF11, x, y); y = y + 24
  print_io_value("NR12", 0xFF12, x, y); y = y + 24
  print_io_value("NR13", 0xFF13, x, y); y = y + 24
  print_io_value("NR14", 0xFF14, x, y); y = y + 24
  y = y + 24
  print_io_value("NR21", 0xFF16, x, y); y = y + 24
  print_io_value("NR22", 0xFF17, x, y); y = y + 24
  print_io_value("NR23", 0xFF18, x, y); y = y + 24
  print_io_value("NR24", 0xFF19, x, y); y = y + 24
  y = y + 24
  print_io_value("NR30", 0xFF1A, x, y); y = y + 24
  print_io_value("NR31", 0xFF1B, x, y); y = y + 24
  print_io_value("NR32", 0xFF1C, x, y); y = y + 24
  print_io_value("NR33", 0xFF1D, x, y); y = y + 24
  print_io_value("NR34", 0xFF1E, x, y); y = y + 24
  y = y + 24
  print_io_value("NR41", 0xFF20, x, y); y = y + 24
  print_io_value("NR42", 0xFF21, x, y); y = y + 24
  print_io_value("NR43", 0xFF22, x, y); y = y + 24
  print_io_value("NR44", 0xFF23, x, y); y = y + 24
  y = y + 24
  print_io_value("NR50", 0xFF24, x, y); y = y + 24
  print_io_value("NR51", 0xFF25, x, y); y = y + 24
  print_io_value("NR52", 0xFF26, x, y); y = y + 24
  -- WHEW
end

function draw_game_screen(dx, dy, scale)
  love.graphics.setCanvas(game_screen_canvas)
  love.graphics.clear()
  for y = 0, 143 do
    for x = 0, 159 do
      love.graphics.setColor(game_screen[y][x][1], game_screen[y][x][2], game_screen[y][x][3], 255)
      love.graphics.point(0.5 + x, 0.5 + y)
    end
  end
  love.graphics.setColor(255, 255, 255)
  love.graphics.setCanvas() -- reset to main FB
  love.graphics.push()
  love.graphics.scale(scale, scale)
  love.graphics.draw(game_screen_canvas, dx / scale, dy / scale)
  love.graphics.pop()
end

function draw_tile(address, sx, sy)
  local x = 0
  local y = 0
  for y = 0, 7 do
    for x = 0, 7 do
      color = getColorFromTile(address, x, y)
      love.graphics.setColor(color[1], color[2], color[3])
      love.graphics.point(0.5 + sx + x, 0.5 + sy + y)
    end
  end
end

function draw_tiles(dx, dy, tiles_across, scale)
  love.graphics.setCanvas(debug_tile_canvas)
  love.graphics.clear()
  local tile_address = 0x8000
  local x = 0
  local y = 0
  for i = 0, 384 - 1 do
    draw_tile(tile_address, x, y)
    x = x + 8
    if x >= tiles_across * 8 then
      x = 0
      y = y + 8
    end
    tile_address = tile_address + 16
  end
  love.graphics.setColor(255, 255, 255)
  love.graphics.setCanvas() -- reset to main FB
  love.graphics.push()
  love.graphics.scale(scale, scale)
  love.graphics.draw(debug_tile_canvas, dx / scale, dy / scale)
  love.graphics.pop()
end

function draw_tilemap(dx, dy, address, scale)
  love.graphics.setCanvas(debug_tile_canvas)
  love.graphics.clear()
  for y = 0, 255 do
    for x = 0, 255 do
      local color = getColorFromTilemap(address, x, y)
      love.graphics.setColor(color[1], color[2], color[3])
      love.graphics.point(0.5 + x, 0.5 + y)
    end
  end
  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(255, 255, 255)
  love.graphics.push()
  love.graphics.scale(scale, scale)
  love.graphics.draw(debug_tile_canvas, dx / scale, dy / scale)
  love.graphics.pop()
end

function run_one_opcode()
  update_graphics()
  update_input()
  return process_instruction()
end

function love.textinput(char)
  if char == " " then
    run_one_opcode()
  end
  if char == "k" then
    for i = 1, 1000 do
      run_one_opcode()
    end
  end
  if char == "h" then
    old_scanline = scanline()
    while old_scanline == scanline() do
      run_one_opcode()
    end
  end
  if char == "v" then
    while scanline() == 144 do
      run_one_opcode()
    end
    while scanline() ~= 144 do
      run_one_opcode()
    end
  end
end

function draw_background()
  draw_tilemap(0, 500, 0x9800, 1)
end

function draw_window()
  draw_tilemap(512, 500, 0x9C00, 1)
end

function love.draw()
  love.graphics.setFont(ubuntu_font)
  print_register_values()
  print_instructions()
  print_io_values()
  draw_game_screen(0, 200, 2)
  draw_tiles(320, 200, 32, 2)
  draw_window()
  draw_background()
end
