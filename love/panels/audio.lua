local bit32 = require("bit")

local audio = {}

audio.width = 136 * 2

audio.init = function(gameboy)
  audio.canvas = love.graphics.newCanvas(audio.width / 2, 400)
  audio.gameboy = gameboy
  audio.graph_canvas = love.graphics.newCanvas(136, 64)
  audio.font = love.graphics.newImageFont("images/5x3font_bm.png", " !\"#$%'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~ ", 1)
end

audio.draw_graph = function(x, y, table, start, size, disabled)
  love.graphics.setCanvas(audio.graph_canvas)
  love.graphics.clear()
  love.graphics.setLineWidth(1)
  love.graphics.setLineStyle("rough")
  love.graphics.setColor(128, 128, 128)
  love.graphics.rectangle("line", 6, 2, 127, 32)
  if disabled then
    love.graphics.setColor(128, 128, 128)
    love.graphics.rectangle("fill", 4, 0, 128, 32)
    love.graphics.setColor(192, 192, 192)
  else
    love.graphics.setColor(255, 255, 255)
    love.graphics.rectangle("fill", 4, 0, 128, 32)
    love.graphics.setColor(0, 0, 0)
  end
  for i = 0, size - 1 do
    local sample = table[(start + i) % size] * -1
    local sample_next = table[(start + i + 1) % size] * -1
    love.graphics.line(i + 4, 16 * sample + 16, i + 1 + 4, 16 * sample_next + 16)
  end
  love.graphics.setColor(0, 0, 0)
  love.graphics.rectangle("line", 5, 1, 127, 32)
  love.graphics.setCanvas(audio.canvas)
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(audio.graph_canvas, x, y)
end

audio.draw = function(x, y)
  love.graphics.setCanvas(audio.canvas)
  love.graphics.clear()
  love.graphics.setColor(192, 192, 192)
  love.graphics.rectangle("fill", 0, 0, 136, 400)
  love.graphics.setColor(255, 255, 255)

  local debug = audio.gameboy.audio.debug
  love.graphics.setFont(audio.font)
  love.graphics.print("Tone 1", 2, 4)
  audio.draw_graph(0, 10, debug.tone1, debug.current_sample, debug.max_samples, audio.gameboy.audio.tone1.debug_disabled)
  love.graphics.print("Tone 2", 2, 49)
  audio.draw_graph(0, 55, debug.tone2, debug.current_sample, debug.max_samples, audio.gameboy.audio.tone2.debug_disabled)
  love.graphics.print("Wave", 2, 94)
  audio.draw_graph(0, 100, debug.wave3, debug.current_sample, debug.max_samples, audio.gameboy.audio.wave3.debug_disabled)
  love.graphics.print("Noise", 2, 139)
  audio.draw_graph(0, 145, debug.noise4, debug.current_sample, debug.max_samples, audio.gameboy.audio.noise4.debug_disabled)

  love.graphics.print("Final Output", 2, 204)
  audio.draw_graph(0, 210, debug.final, debug.current_sample, debug.max_samples)

  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(255, 255, 255)
  love.graphics.push()
  love.graphics.scale(2, 2)
  love.graphics.draw(audio.canvas, x / 2, y / 2)
  love.graphics.pop()
end

return audio
