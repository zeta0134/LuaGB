bit32 = require("bit")
gameboy = require("gameboy")
binser = require("vendor/binser")

local panels = {}

panels.registers = require("panels/registers")
panels.io = require("panels/io")
panels.vram = require("panels/vram")
panels.oam = require("panels/oam")

local active_panels = {}

local ubuntu_font

local game_screen_canvas
local debug_tile_canvas

local emulator_running = false
local debug_mode = true

local resize_window = function()
  local width = 160 * 2 --width of gameboy screen
  local height = 144 * 2 --height of gameboy screen
  if debug_mode then
    if #active_panels > 0 then
      width = width + 10
      for _, panel in ipairs(active_panels) do
        width = width + panel.width + 10
      end
    end
    height = 800
  end
  love.window.setMode(width, height)
end

function love.load(args)
  love.graphics.setDefaultFilter("nearest", "nearest")
  --love.graphics.setPointStyle("rough")
  ubuntu_font = love.graphics.newFont("UbuntuMono-R.ttf", 18)
  love.graphics.setFont(ubuntu_font)
  game_screen_canvas = love.graphics.newCanvas(256, 256)

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

  -- Initialize Debug Panels
  for _, panel in pairs(panels) do
    panel.init(gameboy)
    panel.active = true
  end

  table.insert(active_panels, panels.io)
  table.insert(active_panels, panels.vram)
  table.insert(active_panels, panels.oam)

  resize_window()

  love.window.setTitle("LuaGB - " .. gameboy.cartridge.header.title)
end

local function save_state(number)
  local state_data = gameboy.save_state()
  local filename = gameboy.cartridge.header.title .. ".s" .. number
  local state_string = binser.serialize(state_data)
  if love.filesystem.write(filename, state_string) then
    print("Successfully wrote state: ", filename)
  else
    print("Failed to save state: ", filename)
  end
end

local function load_state(number)
  local filename = gameboy.cartridge.header.title .. ".s" .. number
  local file_data, size = love.filesystem.read(filename)
  if type(size) == "string" then
    print(size)
    print("Couldn't load state: ", filename)
  else
    if size > 0 then
      local state_data, elements = binser.deserialize(file_data)
      if elements > 0 then
        gameboy.load_state(state_data[1])
        print("Loaded state: ", filename)
      else
        print("Error parsing state data for ", filename)
      end
    end
  end
end

function print_instructions()
  love.graphics.setColor(255, 255, 255)
  local shortcuts = {
    "[P] = Play/Pause",
    "[R] = Reset",
    "[D] = Toggle Debug Mode",
    "",
    "[Space] = Single Step",
    "[K]     = 100 Steps",
    "[L]     = 1000 Steps",
    "[H] = Run until HBlank",
    "[V] = Run until VBlank",
    "",
    "[F1-F9] = Save State",
    "[1-9]   = Load State"
  }
  for i = 1, #shortcuts do
    love.graphics.print(shortcuts[i], 0, 520 + i * 20)
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

local function run_n_cycles(n)
  for i = 1, n do
    gameboy.step()
  end
end

local action_keys = {}
action_keys.space = function() gameboy.step() end

action_keys.k = function() run_n_cycles(100) end
action_keys.l = function() run_n_cycles(1000) end
action_keys.r = gameboy.reset
action_keys.p = function() emulator_running = not emulator_running end
action_keys.h = gameboy.run_until_hblank
action_keys.v = gameboy.run_until_vblank

action_keys.d = function()
  debug_mode = not debug_mode
  resize_window()
end

for i = 1, 9 do
  action_keys[tostring(i)] = function()
    load_state(i)
  end

  action_keys["f" .. tostring(i)] = function()
    save_state(i)
  end
end

local toggle_panel = function(name)
  if panels[name].active then
    panels[name].active = false
    for index, value in ipairs(active_panels) do
      if value == panels[name] then
        table.remove(active_panels, index)
      end
    end
  else
    panels[name].active = true
    table.insert(active_panels, panels[name])
  end
  resize_window()
end

action_keys.kp1 = function() toggle_panel("io") end
action_keys.kp2 = function() toggle_panel("vram") end
action_keys.kp3 = function() toggle_panel("oam") end

local input_mappings = {}
input_mappings.up = "Up"
input_mappings.down = "Down"
input_mappings.left = "Left"
input_mappings.right = "Right"
input_mappings.x = "A"
input_mappings.z = "B"
input_mappings["return"] = "Start"
input_mappings.rshift = "Select"

function love.keypressed(key)
  if input_mappings[key] then
    gameboy.input.keys[input_mappings[key]] = 1
  end
end

function love.keyreleased(key)
  if action_keys[key] then
    action_keys[key]()
  end

  if input_mappings[key] then
    gameboy.input.keys[input_mappings[key]] = 0
  end

  if key == "escape" then
    love.event.quit()
  end
end

function love.update()
  if emulator_running then
    gameboy.run_until_vblank()
  end
end

function love.draw()
  if debug_mode then
    panels.registers.draw(0, 300)
    print_instructions()
    draw_game_screen(0, 0, 2)
    local panel_x = 160 * 2 + 10 --width of the gameboy canvas in debug mode
    for _, panel in pairs(active_panels) do
      panel.draw(panel_x, 0)
      panel_x = panel_x + panel.width + 10
    end
  else
    draw_game_screen(0, 0, 2)
  end
end
