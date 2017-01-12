local bit32 = require("bit")

local audio = {}

audio.width = 256

audio.init = function(gameboy)
  audio.canvas = love.graphics.newCanvas(audio.width, 800)
  audio.gameboy = gameboy
  audio.graph_canvas = love.graphics.newCanvas(256, 64)
end

audio.draw_graph = function(x, y, table, start, size, disabled)
  love.graphics.setCanvas(audio.graph_canvas)
  love.graphics.clear()
  if disabled then
    love.graphics.setColor(32, 32, 32)
    love.graphics.rectangle("fill", 0, 0, 256, 64)
    love.graphics.setColor(128, 128, 128)
  else
    love.graphics.setColor(32, 48, 64)
    love.graphics.rectangle("fill", 0, 0, 256, 64)
    love.graphics.setColor(128, 196, 255)
  end
  love.graphics.setLineWidth(1)
  for i = 0, size - 1 do
    local sample = table[(start + i) % size] * -1
    local sample_next = table[(start + i + 1) % size] * -1
    love.graphics.line(i, 32 * sample + 32, i + 1, 32 * sample_next + 32)
  end
  love.graphics.setCanvas(audio.canvas)
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(audio.graph_canvas, x, y)
end

audio.draw = function(x, y)
  love.graphics.setCanvas(audio.canvas)
  love.graphics.clear()

  local debug = audio.gameboy.audio.debug
  love.graphics.print("Tone 1", 0, 0)
  audio.draw_graph(0, 20, debug.tone1, debug.current_sample, debug.max_samples, audio.gameboy.audio.tone1.debug_disabled)
  love.graphics.print("Tone 2", 0, 90)
  audio.draw_graph(0, 110, debug.tone2, debug.current_sample, debug.max_samples, audio.gameboy.audio.tone2.debug_disabled)
  love.graphics.print("Wave", 0, 180)
  audio.draw_graph(0, 200, debug.wave3, debug.current_sample, debug.max_samples, audio.gameboy.audio.wave3.debug_disabled)
  love.graphics.print("Noise", 0, 270)
  audio.draw_graph(0, 290, debug.noise4, debug.current_sample, debug.max_samples, audio.gameboy.audio.noise4.debug_disabled)

  love.graphics.print("Final Output", 0, 400)
  audio.draw_graph(0, 420, debug.final, debug.current_sample, debug.max_samples)

  love.graphics.setCanvas() -- reset to main FB
  love.graphics.setColor(255, 255, 255)
  love.graphics.draw(audio.canvas, x, y)
end

return audio
