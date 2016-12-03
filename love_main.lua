bit32 = require("bit")

local memory = require("gameboy/memory")
require("gameboy/z80")
local graphics = require("gameboy/graphics")
require("gameboy/rom_header")
local input = require("gameboy/input")

local ubuntu_font

local game_screen_canvas
local debug_tile_canvas

function love.load(args)
  love.window.setMode(1280,800)
  love.graphics.setDefaultFilter("nearest", "nearest")
  --love.graphics.setPointStyle("rough")
  ubuntu_font = love.graphics.newFont("UbuntuMono-R.ttf", 24)
  love.graphics.setFont(ubuntu_font)
  game_screen_canvas = love.graphics.newCanvas(256, 256)
  debug_tile_canvas = love.graphics.newCanvas(256, 256)

  local game_name = "games/" .. args[2]

  file_data, size = love.filesystem.read(game_name)
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
  memory.initialize()
  print("Done!")

  print("Initializing graphics...")
  graphics.initialize()
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
  love.graphics.print(string.format("BC: %04X (BC): %02X", reg.bc(), memory.read_byte(reg.bc())), 160, 24)
  love.graphics.setColor(192,128,64)
  love.graphics.print(string.format("DE: %04X (DE): %02X", reg.de(), memory.read_byte(reg.de())), 160, 48)
  love.graphics.setColor(224,196,128)
  love.graphics.print(string.format("HL: %04X (HL): %02X", reg.hl(), memory.read_byte(reg.hl())), 160, 72)

  love.graphics.setColor(192, 192, 255)
  love.graphics.print(string.format("SP: %04X (SP): %02X %02X %02X %02X", reg.sp,
                      memory.read_byte(reg.sp),
                      memory.read_byte(reg.sp + 1),
                      memory.read_byte(reg.sp + 2),
                      memory.read_byte(reg.sp + 3)), 0, 120)

  love.graphics.setColor(255, 192, 192)
  love.graphics.print(string.format("PC: %04X (PC): %02X %02X %02X %02X", reg.pc,
                      memory.read_byte(reg.pc),
                      memory.read_byte(reg.pc + 1),
                      memory.read_byte(reg.pc + 2),
                      memory.read_byte(reg.pc + 3)), 0, 144)

  love.graphics.setColor(255, 255, 255)
  love.graphics.print(string.format("Clock: %d", clock), 380, 0)
  love.graphics.print(string.format("GPU: Mode: %d", graphics.Status.Mode()), 380, 24)
  love.graphics.print(string.format("Scanline: %d", graphics.scanline()), 380, 48)
  love.graphics.print(string.format("Frame: %d", graphics.vblank_count), 380, 72)
  love.graphics.print(string.format("Halted: %d  IME: %d  IE: %02X  IF: %02X", halted, interrupts_enabled, memory.read_byte(0xFFFF), memory.read_byte(0xFF0F)), 0, 168)
end

function print_instructions()
  love.graphics.setColor(255, 255, 255)
  love.graphics.print("[Space] = Step | [R] = Run | [P] = Pause | [H] = Run until HBlank | [V] = Run until VBlank", 0, 780)
  --print("[Space] = Step | [K] = Run 1000")
  --print("[R] = Run Until Error or Breakpoint")
  --print("[V] = Run Until VBlank")
  --print("[H] = Run until HBlank")
  --print("Draw: [T] Tiles, [B] = BG, [W] = Window, [S] = Sprites, [D] = Entire Screen")
end

function print_io_value(name, address, x, y)
  love.graphics.print(string.format("%04X [%- 4s] %02X", address, name, memory[address]), x, y)
end

local io_values = {
  [850] = {
    -- joypad
    {0xFF00, "JOY"},
    -- serial transfer cable (unimplemented entirely)
    {0xFF01, "SB"},
    {0xFF02, "SC"},
    -- timers
    {0xFF04, "DIV"},
    {0xFF05, "TIMA"},
    {0xFF06, "TMA"},
    {0xFF07, "TAC"},
    -- interrupt flags (this holds currently requested interrupts)
    {0xFF0F, "IF"},
    -- graphics
    {0xFF40, "LCDC"},
    {0xFF41, "STAT"},
    {0xFF42, "SCY"},
    {0xFF43, "SCX"},
    {0xFF44, "LY"},
    {0xFF45, "LYC"},
    {0xFF47, "BGP"},
    {0xFF48, "OBP0"},
    {0xFF49, "OBP1"},
    {0xFF4A, "WY"},
    {0xFF4B, "WX"},
    -- Interrupt enable
    {0xFFFF, "IE"}
  },
  [1100] = {
    -- sound
    {0xFF10, "NR10"},
    {0xFF11, "NR11"},
    {0xFF12, "NR12"},
    {0xFF13, "NR13"},
    {0xFF14, "NR14"},
    {},
    {0xFF16, "NR21"},
    {0xFF17, "NR22"},
    {0xFF18, "NR23"},
    {0xFF19, "NR24"},
    {},
    {0xFF1A, "NR30"},
    {0xFF1B, "NR31"},
    {0xFF1C, "NR32"},
    {0xFF1D, "NR33"},
    {0xFF1E, "NR34"},
    {},
    {0xFF20, "NR41"},
    {0xFF21, "NR42"},
    {0xFF22, "NR43"},
    {0xFF23, "NR44"},
    {},
    {0xFF24, "NR50"},
    {0xFF25, "NR51"},
    {0xFF26, "NR52"},
  }
}

function print_io_values()
  love.graphics.setColor(255, 255, 255)
  for x, column in pairs(io_values) do
    for i, io_value in ipairs(column) do
      if #io_value == 2 then
        print_io_value(io_value[2], io_value[1], x, 24 * (i - 1))
      end
    end
  end
end

function draw_game_screen(dx, dy, scale)
  love.graphics.setCanvas(game_screen_canvas)
  love.graphics.clear()
  for y = 0, 143 do
    for x = 0, 159 do
      love.graphics.setColor(graphics.game_screen[y][x][1], graphics.game_screen[y][x][2], graphics.game_screen[y][x][3], 255)
      love.graphics.points(0.5 + x, 0.5 + y)
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
      local color = graphics.getColorFromTile(address, x, y)
      love.graphics.setColor(color[1], color[2], color[3])
      love.graphics.points(0.5 + sx + x, 0.5 + sy + y)
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
      local color = graphics.getColorFromTilemap(address, x, y)
      love.graphics.setColor(color[1], color[2], color[3])
      love.graphics.points(0.5 + x, 0.5 + y)
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
  graphics.update()
  input.update()
  return process_instruction()
end

local emulator_running = false

function love.textinput(char)
  if char == " " then
    run_one_opcode()
  end
  if char == "r" then
    emulator_running = true
  end
  if char == "p" then
    emulator_running = false
  end
  if char == "h" then
    old_scanline = graphics.scanline()
    while old_scanline == graphics.scanline() do
      run_one_opcode()
    end
  end
  if char == "v" then
    while graphics.scanline() == 144 do
      run_one_opcode()
    end
    while graphics.scanline() ~= 144 do
      run_one_opcode()
    end
  end
end

function love.keypressed(key)
  if key == "up" then
    input.keys.Up = 1
  end
  if key == "down" then
    input.keys.Down = 1
  end
  if key == "left" then
    input.keys.Left = 1
  end
  if key == "right" then
    input.keys.Right = 1
  end
  if key == "x" then
    input.keys.A = 1
  end
  if key == "z" then
    input.keys.B = 1
  end
  if key == "return" then
    input.keys.Start = 1
  end
  if key == "rshift" then
    input.keys.Select = 1
  end
  if key == "escape" then
    love.event.quit()
  end
end

function love.keyreleased(key)
  if key == "up" then
    input.keys.Up = 0
  end
  if key == "down" then
    input.keys.Down = 0
  end
  if key == "left" then
    input.keys.Left = 0
  end
  if key == "right" then
    input.keys.Right = 0
  end
  if key == "x" then
    input.keys.A = 0
  end
  if key == "z" then
    input.keys.B = 0
  end
  if key == "return" then
    input.keys.Start = 0
  end
  if key == "rshift" then
    input.keys.Select = 0
  end
end

function draw_background()
  draw_tilemap(0, 500, 0x9800, 1)
end

function draw_window()
  draw_tilemap(512, 500, 0x9C00, 1)
end

function love.update()
  if emulator_running then
    -- Run until a vblank happens
    while graphics.scanline() == 144 do
      run_one_opcode()
    end
    while graphics.scanline() ~= 144 do
      run_one_opcode()
    end
  end
end

function love.draw()
  if emulator_running then
    draw_game_screen(0, 200, 2)
  else
    print_register_values()
    print_instructions()
    print_io_values()
    draw_game_screen(0, 200, 2)
    draw_tiles(320, 200, 32, 2)
    draw_window()
    draw_background()
  end
end
