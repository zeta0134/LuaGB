local pack = function(...)
    return {..., n = select("#", ...)}
end
local require_loads = {
  bit32 = pack(bit),
  bit = pack(bit)
}
love = {
  _VERSION = 0,
  require = function(s) 
    if (not require_loads[s]) then
      require_loads[s] = pack(include("luagb/"..s..".lua"))
    end
    return unpack(require_loads[s], require_loads[s].n)
  end,
}
love.image = love.require "image"
love.graphics = love.require "graphics"
love.filesystem = love.require "filesystem"
love.window = love.require "window"
love.audio = love.require "audio"
love.sound = love.require "sound"
love.timer = love.require "timer"

love.__love_handler = function(err, ...)
  if (not err) then
    error((...))
  end
  return ...
end

love.__love_resume = function(co, ...)
  return love.__love_handler(coroutine.resume(co, ...))
end

love.__love_yield = function(...)
  return coroutine.yield(...)
end

return love