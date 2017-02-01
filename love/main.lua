local bit32 = require("bit")
local filebrowser = require("filebrowser")
local gameboy = require("gameboy")
local binser = require("vendor/binser")

local panels = {}

panels.audio = require("panels/audio")
panels.registers = require("panels/registers")
panels.io = require("panels/io")
panels.vram = require("panels/vram")
panels.oam = require("panels/oam")
panels.disassembler = require("panels/disassembler")

require("vendor/profiler")

local active_panels = {}

local ubuntu_font

local game_screen_image
local game_screen_imagedata
local debug_tile_canvas

local emulator_running = false
local debug_mode = false
local menu_active = true
local game_loaded = false

local screen_scale = 3

local resize_window = function()
  local scale = screen_scale
  if debug_mode then
    scale = 2
  end
  local width = 160 * scale --width of gameboy screen
  local height = 144 * scale --height of gameboy screen
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

local game_filename = ""
local window_title = ""
local save_delay = 0

-- GLOBAL ON PURPOSE
profile_enabled = false

local function save_ram()
  local filename = "saves/" .. game_filename .. ".sav"
  local save_data = binser.serialize(gameboy.cartridge.external_ram)
  if love.filesystem.write(filename, save_data) then
    print("Successfully wrote SRAM to: ", filename)
  else
    print("Failed to save SRAM: ", filename)
  end
end

local function load_ram()
  local filename = "saves/" .. game_filename .. ".sav"
  local file_data, size = love.filesystem.read(filename)
  if type(size) == "string" then
    print(size)
    print("Couldn't load SRAM: ", filename)
  else
    if size > 0 then
      local save_data, elements = binser.deserialize(file_data)
      if elements > 0 then
        for i = 0, #save_data[1] do
          gameboy.cartridge.external_ram[i] = save_data[1][i]
        end
        print("Loaded SRAM: ", filename)
      else
        print("Error parsing SRAM data for ", filename)
      end
    end
  end
end

local function save_state(number)
  local state_data = gameboy.save_state()
  local filename = "states/" .. game_filename .. ".s" .. number
  local state_string = binser.serialize(state_data)
  if love.filesystem.write(filename, state_string) then
    print("Successfully wrote state: ", filename)
  else
    print("Failed to save state: ", filename)
  end
end

local function load_state(number)
  local filename = "states/" .. game_filename .. ".s" .. number
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

local sound_buffer = nil

function play_gameboy_audio(buffer)
  --local data = love.sound.newSoundData(32768, 32768, 16, 2)
  for i = 0, 32768 - 1 do
    sound_buffer:setSample(i, buffer[i])
  end
  local source = love.audio.newSource(sound_buffer)
  love.audio.play(source)
end

function dump_audio(buffer)
  -- play the sound still
  play_gameboy_audio(buffer)
  -- convert this to a bytestring for output
  local output = ""
  local chars = {}
  for i = 0, 32768 - 1 do
    local sample = buffer[i]
    sample = math.floor(sample * (32768 - 1)) -- re-root in 16-bit range
    chars[i * 2] = string.char(bit32.band(sample, 0xFF))
    chars[i * 2 + 1] = string.char(bit32.rshift(bit32.band(sample, 0xFF00), 8))
  end
  output = table.concat(chars)

  love.filesystem.append("audiodump.raw", output, 32768 * 2)
end

local function load_game(game_path)
  gameboy.reset()

  game_filename = game_path
  while string.find(game_filename, "/") do
    game_filename = string.sub(game_filename, string.find(game_filename, "/") + 1)
  end

  file_data, size = love.filesystem.read(game_path)
  if file_data then
    gameboy.cartridge.load(file_data, size)
    load_ram()
  else
    print("Couldn't open ", game_path, " bailing.")
    love.event.quit()
    return
  end

  window_title = "LuaGB - " .. gameboy.cartridge.header.title
  love.window.setTitle(window_title)

  menu_active = false
  emulator_running = true
  game_loaded = true
end

function love.load(args)
  window_title = "LuaGB"
  sound_buffer = love.sound.newSoundData(32768, 32768, 16, 2)
  love.graphics.setDefaultFilter("nearest", "nearest")
  --love.graphics.setPointStyle("rough")
  ubuntu_font = love.graphics.newFont("UbuntuMono-R.ttf", 18)
  love.graphics.setFont(ubuntu_font)
  --game_screen_canvas = love.graphics.newCanvas(256, 256)
  game_screen_imagedata = love.image.newImageData(256, 256)
  game_screen_image = love.graphics.newImage(game_screen_imagedata)

  gameboy.initialize()

  if #args >= 2 then
    local game_path = args[2]
    load_game(game_path)
  end

  -- Initialize Debug Panels
  for _, panel in pairs(panels) do
    panel.init(gameboy)
  end

  toggle_panel("audio")

  filebrowser.is_directory = love.filesystem.isDirectory
  filebrowser.get_directory_items = love.filesystem.getDirectoryItems
  filebrowser.load_file = load_game
  filebrowser.init(gameboy)

  resize_window()
  gameboy.audio.on_buffer_full(play_gameboy_audio)
  love.audio.setVolume(0.1)
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
    "[1-9]   = Load State",
    "[Numpad] = Debug Panels"
  }
  for i = 1, #shortcuts do
    love.graphics.print(shortcuts[i], 0, 500 + i * 20)
  end
end

function draw_game_screen(dx, dy, scale)
  for y = 0, 143 do
    for x = 0, 159 do
      game_screen_imagedata:setPixel(x, y, gameboy.graphics.game_screen[y][x][1], gameboy.graphics.game_screen[y][x][2], gameboy.graphics.game_screen[y][x][3], 255)
    end
  end
  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(255, 255, 255)
  love.graphics.push()
  love.graphics.scale(scale, scale)
  game_screen_image:refresh()
  love.graphics.draw(game_screen_image, dx / scale, dy / scale)
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

for i = 1, 8 do
  action_keys[tostring(i)] = function()
    load_state(i)
  end

  action_keys["f" .. tostring(i)] = function()
    save_state(i)
  end
end

action_keys["f9"] = function() gameboy.audio.tone1.debug_disabled = not gameboy.audio.tone1.debug_disabled end
action_keys["f10"] = function() gameboy.audio.tone2.debug_disabled = not gameboy.audio.tone2.debug_disabled end
action_keys["f11"] = function() gameboy.audio.wave3.debug_disabled = not gameboy.audio.wave3.debug_disabled end
action_keys["f12"] = function() gameboy.audio.noise4.debug_disabled = not gameboy.audio.noise4.debug_disabled end

action_keys.kp1 = function() toggle_panel("io") end
action_keys.kp2 = function() toggle_panel("vram") end
action_keys.kp3 = function() toggle_panel("oam") end
action_keys.kp4 = function() toggle_panel("disassembler") end
action_keys.kp5 = function() toggle_panel("audio") end

action_keys["kp+"] = function()
  if screen_scale < 5 then
    screen_scale = screen_scale + 1
    resize_window()
  end
end

action_keys["kp-"] = function()
  if screen_scale > 1 then
    screen_scale = screen_scale - 1
    resize_window()
  end
end

local audio_dump_running = false
action_keys.a = function()
  if audio_dump_running then
    gameboy.audio.on_buffer_full(play_gameboy_audio)
    print("Stopped dumping audio.")
    audio_dump_running = false
  else
    love.filesystem.remove("audiodump.raw")
    gameboy.audio.on_buffer_full(dump_audio)
    print("Started dumping audio to audiodump.raw ...")
    audio_dump_running = true
  end
end

action_keys.lshift = function() profile_enabled = not profile_enabled end

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
    gameboy.input.update()
  end
end

function love.keyreleased(key)
  if not profile_enabled or key == "lshift" then
    if action_keys[key] then
      action_keys[key]()
    end
  end

  if menu_active then
    filebrowser.keyreleased(key)
  end

  if input_mappings[key] then
    gameboy.input.keys[input_mappings[key]] = 0
    gameboy.input.update()
  end

  if key == "escape" and game_loaded then
    menu_active = not menu_active
  end
end

function love.update()
  if profile_enabled then
    profilerStart()
  end
  if menu_active then
    filebrowser.update()
  else
    if emulator_running then
      gameboy.run_until_vblank()
    end
  end
  if gameboy.cartridge.external_ram.dirty then
    save_delay = save_delay + 1
  end
  if save_delay > 60 * 10 then
    save_delay = 0
    gameboy.cartridge.external_ram.dirty = false
    save_ram()
  end
  if profile_enabled then
    profilerStop()
  end
end

function love.draw()
  if debug_mode then
    panels.registers.draw(0, 300)
    print_instructions()
    if menu_active then
      filebrowser.draw()
    else
      draw_game_screen(0, 0, 2)
    end
    local panel_x = 160 * 2 + 10 --width of the gameboy canvas in debug mode
    for _, panel in pairs(active_panels) do
      panel.draw(panel_x, 0)
      panel_x = panel_x + panel.width + 10
    end
  else
    if menu_active then
      filebrowser.draw(0, 0, screen_scale)
    else
      draw_game_screen(0, 0, screen_scale)
    end
  end

  if profile_enabled then
    love.graphics.setColor(0, 0, 0, 128)
    love.graphics.rectangle("fill", 0, 0, 1024, 1024)
    love.graphics.setColor(255, 255, 255)
  end

  love.window.setTitle("(FPS: " .. love.timer.getFPS() .. ") - " .. window_title)
end

function love.quit()
  profilerReport("profiler.txt")
  if game_loaded then
    save_ram()
  end
end
