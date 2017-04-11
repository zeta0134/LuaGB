local audio = {}

local function NOIMPL(name)
    return function() end
end

audio.play = NOIMPL "play"
audio.newSource = NOIMPL "newSource"
audio.stop = NOIMPL "stop"

return audio