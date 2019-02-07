local io = {}

io.width = 64 * 2

io.init = function()
  io.canvas = love.graphics.newCanvas(64, 400)
  io.background_image = love.graphics.newImage("images/debug_io_background.png")
end

io.draw = function(x, y, gameboy)
  love.graphics.setCanvas(io.canvas)
  love.graphics.clear()
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(io.background_image, 0, 0)
  io.print_values(gameboy)
  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(1, 1, 1)
  love.graphics.push()
  love.graphics.scale(2, 2)
  love.graphics.draw(io.canvas, x / 2, y / 2)
  love.graphics.pop()
end

local io_values = {
  [0] = {
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
    {0xFFFF, "IE"},
    {},

    -- sound
    {0xFF10, "NR10"},
    {0xFF11, "NR11"},
    {0xFF12, "NR12"},
    {0xFF13, "NR13"},
    {0xFF14, "NR14"},
    --{},
    {0xFF16, "NR21"},
    {0xFF17, "NR22"},
    {0xFF18, "NR23"},
    {0xFF19, "NR24"},
    --{},
    {0xFF1A, "NR30"},
    {0xFF1B, "NR31"},
    {0xFF1C, "NR32"},
    {0xFF1D, "NR33"},
    {0xFF1E, "NR34"},
    --{},
    {0xFF20, "NR41"},
    {0xFF21, "NR42"},
    {0xFF22, "NR43"},
    {0xFF23, "NR44"},
    --{},
    {0xFF24, "NR50"},
    {0xFF25, "NR51"},
    {0xFF26, "NR52"},
  }
}

function io.print_value(gameboy, name, address, x, y)
  love.graphics.print(string.format("%04X [%- 4s] %02X", address, name, gameboy.memory[address]), x, y)
end

function io.print_values(gameboy)
  love.graphics.setColor(0, 0, 0)
  for x, column in pairs(io_values) do
    for i, io_value in ipairs(column) do
      if #io_value == 2 then
        io.print_value(gameboy, io_value[2], io_value[1], 4 + x, 7 * (i) + 10)
      end
    end
  end
end

return io
