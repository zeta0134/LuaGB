local filebrowser = {}

filebrowser.pwd = "games/"

filebrowser.items = {}

filebrowser.init = function()
  filebrowser.canvas = love.graphics.newCanvas(160,144)
end

filebrowser.refresh_items = function()
  filebrowser.items = love.filesystem.getDirectoryItems(filebrowser.pwd)
end

filebrowser.draw = function()
  love.graphics.setCanvas(filebrowser.canvas)
  love.graphics.clear()
  love.graphics.setColor(0, 0, 0, 128)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  local y = 0
  for _, item in pairs(filebrowser.items) do
    love.graphics.setColor(255, 255, 0)
    love.graphics.print(item, 0, y)
    y = y + 20
  end
  love.graphics.setCanvas()
  love.graphics.setColor(255, 255, 255)
  love.graphics.push()
  love.graphics.scale(2, 2)
  love.graphics.draw(filebrowser.canvas, 0, 0)
  love.graphics.pop()
end

return filebrowser
