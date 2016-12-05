bit32 = require("bit")
gameboy = require("gameboy")

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

  if #args < 2 then
    print("Usage: love love [path to game.gb]")
    love.event.quit()
    return
  end

  local game_path = args[2]

  gameboy.initialize()

  file_data, size = love.filesystem.read(game_path)
  if file_data then
    gameboy.cartridge.load(file_data, size)
  else
    print("Couldn't open ", game_path, " bailing.")
    love.event.quit()
    return
  end
end

function print_register_values()
  local grid = {
    x = {0, 80, 160, 380},
    y = {0, 24, 48, 72, 120, 144, 168}
  }

  local function get_register(name)
    return function() return reg[name] end
  end
  local registers = {
    {255, 255, 64, "A", get_register("a"), 1, 1},
    {64, 128, 64, "F", reg.f, 2, 1},
    {108, 108, 255, "B", get_register("b"), 1, 2},
    {152, 80, 32, "C", get_register("c"), 2, 2},
    {192, 128, 64, "D", get_register("d"), 1, 3},
    {64, 255, 64, "E", get_register("e"), 2, 3},
    {224, 196, 128, "H", get_register("h"), 1, 4},
    {255, 255, 255, "L", get_register("l"), 2, 4}
  }
  for _, register in ipairs(registers) do
    local r, g, b = register[1], register[2], register[3]
    local name, accessor = register[4], register[5]
    local x, y = register[6], register[7]

    love.graphics.setColor(r, g, b)
    love.graphics.print(string.format("%s: %02X", name, accessor()), grid.x[x], grid.y[y])
  end

  local function flag_string(flag) return reg.flags[flag] == 1 and flag or "" end
  love.graphics.setColor(192, 192, 192)
  love.graphics.print(string.format("Flags: [%1s %1s %1s %1s])", flag_string("c"), flag_string("n"), flag_string("h"), flag_string("z")), grid.x[3], grid.y[0])

  local wide_registers = {
    {108, 108, 255, "BC", "bc", 3, 2},
    {192, 128, 64, "DE", "de", 3, 3},
    {224, 196, 128, "HL", "hl", 3, 4}
  }
  for _, register in ipairs(wide_registers) do
    local r, g, b = register[1], register[2], register[3]
    local name, accessor = register[4], register[5]
    local x, y = register[6], register[7]
    local value = reg[accessor]()
    local indirect_value = gameboy.memory.read_byte(value)

    love.graphics.setColor(r, g, b)
    love.graphics.print(string.format("%s: %04X (%s): %02X", name, value, name, indirect_value), grid.x[x], grid.y[y])
  end

  local pointer_registers = {
    {192, 192, 255, "SP", "sp", 1, 5},
    {255, 192, 192, "PC", "pc", 1, 6}
  }
  for _, register in ipairs(pointer_registers) do
    local r, g, b = register[1], register[2], register[3]
    local name, accessor = register[4], register[5]
    local x, y = register[6], register[7]
    local value = reg[accessor]

    love.graphics.setColor(r, g, b)
    love.graphics.print(string.format("%s: %04X (%s): %02X %02X %02X %02X", name, value, name,
                                      gameboy.memory.read_byte(value),
                                      gameboy.memory.read_byte(value + 1),
                                      gameboy.memory.read_byte(value + 2),
                                      gameboy.memory.read_byte(value + 3)), grid.x[x], grid.y[y])
  end

  local status = {
    {"Clock", function() return clock end, 4, 1},
    {"GPU Mode", gameboy.graphics.Status.Mode, 4, 2},
    {"Scanline", gameboy.graphics.scanline, 4, 3},
    {"Frame", function() return gameboy.graphics.vblank_count end, 4, 4}
  }
  love.graphics.setColor(255, 255, 255)
  for _, state in ipairs(status) do
    local name, accessor = state[1], state[2]
    local x, y = state[3], state[4]

    love.graphics.print(string.format("%s: %d", name, accessor()), grid.x[x], grid.y[y])
  end

  love.graphics.print(string.format("Halted: %d  IME: %d  IE: %02X  IF: %02X", halted, interrupts_enabled, gameboy.memory.read_byte(0xFFFF), gameboy.memory.read_byte(0xFF0F)), grid.x[1], grid.y[7])
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
  love.graphics.print(string.format("%04X [%- 4s] %02X", address, name, gameboy.memory[address]), x, y)
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
      love.graphics.setColor(gameboy.graphics.game_screen[y][x][1], gameboy.graphics.game_screen[y][x][2], gameboy.graphics.game_screen[y][x][3], 255)
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
      local color = gameboy.graphics.getColorFromTile(address, x, y)
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
      local color = gameboy.graphics.getColorFromTilemap(address, x, y)
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
  gameboy.graphics.update()
  gameboy.input.update()
  return process_instruction()
end

local emulator_running = false

function love.textinput(char)
  if char == " " then
    run_one_opcode()
  end
  if char == "k" then
    for i = 1, 100 do
      run_one_opcode()
    end
  end
  if char == "l" then
    for i = 1, 1000 do
      run_one_opcode()
    end
  end
  if char == "r" then
    emulator_running = true
  end
  if char == "p" then
    emulator_running = false
  end
  if char == "h" then
    old_scanline = gameboy.graphics.scanline()
    local instructions = 0
    while old_scanline == gameboy.graphics.scanline() and instructions < 100000  do
      run_one_opcode()
      instructions = instructions + 1
    end
  end
  if char == "v" then
    local instructions = 0
    while gameboy.graphics.scanline() == 144 and instructions < 100000 do
      run_one_opcode()
      instructions = instructions + 1
    end
    while gameboy.graphics.scanline() ~= 144 and instructions < 100000  do
      run_one_opcode()
      instructions = instructions + 1
    end
  end
end

function love.keypressed(key)
  if key == "up" then
    gameboy.input.keys.Up = 1
  end
  if key == "down" then
    gameboy.input.keys.Down = 1
  end
  if key == "left" then
    gameboy.input.keys.Left = 1
  end
  if key == "right" then
    gameboy.input.keys.Right = 1
  end
  if key == "x" then
    gameboy.input.keys.A = 1
  end
  if key == "z" then
    gameboy.input.keys.B = 1
  end
  if key == "return" then
    gameboy.input.keys.Start = 1
  end
  if key == "rshift" then
    gameboy.input.keys.Select = 1
  end
  if key == "escape" then
    love.event.quit()
  end
end

function love.keyreleased(key)
  if key == "up" then
    gameboy.input.keys.Up = 0
  end
  if key == "down" then
    gameboy.input.keys.Down = 0
  end
  if key == "left" then
    gameboy.input.keys.Left = 0
  end
  if key == "right" then
    gameboy.input.keys.Right = 0
  end
  if key == "x" then
    gameboy.input.keys.A = 0
  end
  if key == "z" then
    gameboy.input.keys.B = 0
  end
  if key == "return" then
    gameboy.input.keys.Start = 0
  end
  if key == "rshift" then
    gameboy.input.keys.Select = 0
  end
end

function draw_background()
  draw_tilemap(0, 500, 0x9800, 1)
end

function draw_window()
  draw_tilemap(512, 500, 0x9C00, 1)
end

function love.update()
  local instructions = 0
  if emulator_running then
    -- Run until a vblank happens, OR we run too many instructions in one go
    while gameboy.graphics.scanline() == 144 and instructions < 100000 do
      run_one_opcode()
      instructions = instructions + 1
    end
    instructions = 0
    while gameboy.graphics.scanline() ~= 144 and instructions < 100000 do
      run_one_opcode()
      instructions = instructions + 1
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
