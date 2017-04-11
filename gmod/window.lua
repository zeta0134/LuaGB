local window = {love = love}

window.close = function()
    window.love.panel:Remove()
end

window.setIcon = function() end

window.setMode = function(width, height, ...)
    assert(select("#", ...) == 0, "flags not supported in window.setMode")
    window.love.panel:SetWindowSize(width, height)
end

window.setTitle = function() end

return window