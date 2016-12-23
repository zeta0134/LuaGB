local opcode_names = require("gameboy/opcode_names")

local disassembler = {}

disassembler.width = 256

disassembler.init = function(gameboy)
  disassembler.canvas = love.graphics.newCanvas(256, 800)
  disassembler.gameboy = gameboy
end

disassembler.draw = function(x, y)
  love.graphics.setCanvas(disassembler.canvas)
  love.graphics.clear()
  love.graphics.print("Disassembly", 0, 0)
  disassembler.print_opcodes(disassembler.gameboy)
  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(disassembler.canvas, x, y)
end

local opcode_string = function(opcode, data1, data2)
  local name = opcode_names[opcode]
  -- Data Values
  if string.find(name, "d8") ~= nil then
    name = string.gsub(name, "d8", string.format("$%02X", data1))
    return name, 2
  end
  if string.find(name, "d16") ~= nil then
    name = string.gsub(name, "d16", string.format("$%02X%02X", data2, data1))
    return name, 3
  end

  -- Relative Values (jumps, stack manipulation, etc)
  if string.find(name, "r8") ~= nil then
    if data1 > 127 then
      data1 = data1 - 256
    end
    name = string.gsub(name, "r8", string.format("%d", data1))
    return name, 2
  end

  -- Addresses
  if string.find(name, "a8") ~= nil then
    name = string.gsub(name, "a8", string.format("$%02X", data1))
    return name, 2
  end
  if string.find(name, "a16") ~= nil then
    name = string.gsub(name, "a16", string.format("$%02X%02X", data2, data1))
    return name, 3
  end

  -- Default case: plain opcode, no data
  return name, 1
end

disassembler.print_opcodes = function(gameboy)
  local y = 30
  local pc = gameboy.z80.registers.pc
  local darken_rows = 0
  for i = 1, math.floor(700 / 20) do
    local name, data_values = opcode_string(gameboy.memory[pc], gameboy.memory[pc + 1], gameboy.memory[pc + 2])
    local color = {255, 255, 255}
    if i ~= 1 then
      if darken_rows > 0 then
        color = {64, 64, 64}
        darken_rows = darken_rows - 1
      else
        color = {192, 192, 192}
      end
    end
    if darken_rows == 0 and data_values > 1 then
      darken_rows = data_values - 1
    end
    love.graphics.setColor(unpack(color))
    love.graphics.print(string.format("%04X: [%02X] %s", pc, gameboy.memory[pc], name), 0, y)
    pc = bit32.band(pc + 1, 0xFFFF)
    y = y + 20
  end
  love.graphics.setColor(255, 255, 255)
end

return disassembler
