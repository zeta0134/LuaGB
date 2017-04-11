local bit32 = luagb.require("bit")

local opcode_names = luagb.require("gameboy/opcode_names")

local disassembler = {}

disassembler.width = 128 * 2

disassembler.init = function(gameboy)
  disassembler.canvas = love.graphics.newCanvas(128, 400)
  disassembler.gameboy = gameboy
  disassembler.background_image = love.graphics.newImage("images/debug_disassembler_background.png")
end

disassembler.draw = function(x, y)
  love.graphics.setCanvas(disassembler.canvas)
  love.graphics.clear()
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(disassembler.background_image, 0, 0)
  disassembler.print_opcodes(disassembler.gameboy)
  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(255, 255, 255)
  love.graphics.push()
  love.graphics.scale(2, 2)
  love.graphics.draw(disassembler.canvas, x / 2, y / 2)
  love.graphics.pop()
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
  local y = 15
  local pc = gameboy.processor.registers.pc
  local darken_rows = 0
  love.graphics.setColor(128, 128, 128)
  love.graphics.rectangle("fill", 0, 14, 128, 7)
  for i = 1, math.floor((400 - 15) / 7) do
    local name, data_values = opcode_string(gameboy.memory[pc], gameboy.memory[pc + 1], gameboy.memory[pc + 2])

    local color = {255, 255, 255}
    if darken_rows > 0 then
      color = {128, 128, 128}
      darken_rows = darken_rows - 1
    else
      if i ~= 1 then
        color = {0, 0, 0}
      end
      if darken_rows == 0 and data_values > 1 then
        darken_rows = data_values - 1
      end
    end
    love.graphics.setColor(unpack(color))
    love.graphics.print(string.format("%04X: [%02X] %s", pc, gameboy.memory[pc], name), 4, y)
    pc = bit32.band(pc + 1, 0xFFFF)
    y = y + 7
  end
  love.graphics.setColor(255, 255, 255)
end

return disassembler
