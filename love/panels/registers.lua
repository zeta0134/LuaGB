local registers = {}

registers.width = 256

local vertical_spacing = 18

registers.init = function(gameboy)
  registers.canvas = love.graphics.newCanvas(512, 800)
  registers.gameboy = gameboy
end

registers.draw = function(x, y)
  love.graphics.setCanvas(registers.canvas)
  love.graphics.clear()
  registers.print_values(registers.gameboy)
  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(registers.canvas, x, y)
end

registers.print_registers = function(gameboy, x, y)
  local function get_register(name)
    return function() return gameboy.z80.registers[name] end
  end

  local registers = {
    {255, 255, 64, "A", get_register("a"), 0, 0},
    {64, 128, 64, "F", gameboy.z80.registers.f, 1, 0},
    {108, 108, 255, "B", get_register("b"), 0, 1},
    {152, 80, 32, "C", get_register("c"), 1, 1},
    {192, 128, 64, "D", get_register("d"), 0, 2},
    {64, 255, 64, "E", get_register("e"), 1, 2},
    {224, 196, 128, "H", get_register("h"), 0, 3},
    {255, 255, 255, "L", get_register("l"), 1, 3}
  }

  for _, register in ipairs(registers) do
    local r, g, b = register[1], register[2], register[3]
    local name, accessor = register[4], register[5]
    local rx, ry = register[6], register[7]

    love.graphics.setColor(r, g, b)
    love.graphics.print(string.format("%s: %02X", name, accessor()), x + rx * 60, y + ry * vertical_spacing)
  end
  love.graphics.setColor(255, 255, 255)
end

registers.print_wide_registers = function(gameboy, x, y)
  local wide_registers = {
    {108, 108, 255, "BC", "bc"},
    {192, 128, 64, "DE", "de"},
    {224, 196, 128, "HL", "hl"}
  }

  local ry = 0
  for _, register in ipairs(wide_registers) do
    local r, g, b = register[1], register[2], register[3]
    local name, accessor = register[4], register[5]
    local value = gameboy.z80.registers[accessor]()
    local indirect_value = gameboy.memory.read_byte(value)

    love.graphics.setColor(r, g, b)
    love.graphics.print(string.format("%s: %04X (%s): %02X", name, value, name, indirect_value), x, y + ry)
    ry = ry + vertical_spacing
  end
  love.graphics.setColor(255, 255, 255)
end

registers.print_flags = function(gameboy, x, y)
  local function flag_string(flag) return gameboy.z80.registers.flags[flag] == 1 and flag or "" end
  love.graphics.setColor(192, 192, 192)
  love.graphics.print(string.format("Flags: [%1s %1s %1s %1s]", flag_string("c"), flag_string("n"), flag_string("h"), flag_string("z")), x, y)
  love.graphics.setColor(255, 255, 255)
end

registers.print_pointer_registers = function(gameboy, x, y)
  local pointer_registers = {
    {192, 192, 255, "SP", "sp"},
    {255, 192, 192, "PC", "pc"}
  }

  local ry = 0
  for _, register in ipairs(pointer_registers) do
    local r, g, b = register[1], register[2], register[3]
    local name, accessor = register[4], register[5]
    local value = gameboy.z80.registers[accessor]

    love.graphics.setColor(r, g, b)
    love.graphics.print(string.format("%s: %04X (%s): %02X %02X %02X %02X", name, value, name,
                                      gameboy.memory.read_byte(value),
                                      gameboy.memory.read_byte(value + 1),
                                      gameboy.memory.read_byte(value + 2),
                                      gameboy.memory.read_byte(value + 3)), x, y + ry)
    ry = ry + vertical_spacing
  end
end

registers.print_status_block = function(gameboy, x, y)
  local status = {
    {"Frame", function() return gameboy.graphics.vblank_count end},
    {"Clock", function() return gameboy.timers.system_clock end}
  }
  love.graphics.setColor(255, 255, 255)
  local rx = 0
  for _, state in ipairs(status) do
    local name, accessor = state[1], state[2]

    love.graphics.print(string.format("%s: %d", name, accessor()), x + rx, y)
    rx = rx + 128
  end

  love.graphics.print(string.format("Halted: %d  IME: %d  IE: %02X  IF: %02X",
    gameboy.z80.halted,
    gameboy.interrupts.enabled,
    gameboy.memory.read_byte(0xFFFF),
    gameboy.memory.read_byte(0xFF0F)), x, y + vertical_spacing)
end

registers.print_values = function(gameboy)
  local grid = {
    x = {0, 80, 160, 380},
    y = {0, 24, 48, 72, 120, 144, 168}
  }

  registers.print_registers(gameboy, 0, 0)
  registers.print_wide_registers(gameboy, 128, 0)
  registers.print_flags(gameboy, 128, vertical_spacing * 3)
  registers.print_pointer_registers(gameboy, 0, vertical_spacing * 5)
  registers.print_status_block(gameboy, 0, vertical_spacing * 7)
end

return registers
