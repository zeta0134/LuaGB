local PANEL = {}

local pack = function(...)
    return {n = select("#", ...), ...}
end

DEFINE_BASECLASS "EditablePanel"

function PANEL:SetLoveInstance(love)
    assert(not love.run, "love.run not supported")
    self.love = love
    love.panel = self
    self.LoveQueue = {}

    self.co = self.co or coroutine.create(function()
        while true do
            local func = self.LoveQueue[1]
            if (func) then
                table.remove(self.LoveQueue, 1)
                local name = func[1]
                if (self.love[name]) then
                    self.love.__love_curfunc = name
                    local time = SysTime
                    local t = time()
                    self.love[name](unpack(func, 2, func.n))
                    print(string.format("%s took %.2f ms", name, (time() - t) * 1000))
                end
            end
            coroutine.yield(false)
        end
    end)

    self.love.__love_co = self.co
end

function PANEL:LoveCall(func, ...)
    local love = self.love
    if (not love) then
        self:Remove()
        error("love not addded with self:SetLoveInstance")
    end
    if (love.__love_incallback and func == "draw") then
        return
    end
    self.LoveQueue[#self.LoveQueue + 1] = pack(func, ...)
    while (#self.LoveQueue > 0 and not love.__love_incallback) do
        local err, msg = coroutine.resume(self.co)
        if (not err) then
            self:Remove()
            error(msg)
        end
    end
    
end

function PANEL:Init()
    self:SetLoveInstance(self.love or love)
    self:LoveCall("load", {})
    --BaseClass.Init(self)
end

function PANEL:Paint()
    --self:LoveCall("run")
    self:LoveCall("draw")
end

function PANEL:OnFocusChanged(gained)
    self:LoveCall("mousefocus", gained)
end

local keycode_to_keyconstant = {}

local function DirectLookup(...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        local keycode = _G["KEY_"..string.upper(name)]
        assert(keycode, "code not found for "..name)
        keycode_to_keyconstant[keycode] = name
    end
end

for b = string.byte("a"), string.byte("z") do
    DirectLookup(string.char(b))
end
for b = string.byte("0"), string.byte("9") do
    DirectLookup(string.char(b))
end
DirectLookup "space"
DirectLookup("up", "down", "right", "left", "home", "end", "pageup", "pagedown")
for i = 1, 12 do
    DirectLookup("f"..i)
end

function PANEL:Think()
    self:LoveCall "update"
end

function PANEL:OnKeyCodePressed(keycode)
print(keycode_to_keyconstant[keycode], "presed")
    self:LoveCall("keypressed", keycode_to_keyconstant[keycode])
end

function PANEL:OnKeyCodeReleased(keycode)
    self:LoveCall("keyreleased", keycode_to_keyconstant[keycode])
end

function PANEL:SetTitle(name)
    self:GetParent():SetTitle(name)
end

function PANEL:SetWindowSize(w, h)
    self:SetSize(w,h)
end

vgui.Register("VGUILove", PANEL, "EditablePanel")

--[[
local PANEL = {}

DEFINE_BASECLASS "DFrame"

function PANEL:Init()
    self.lovechild = vgui.Create("VGUILoveEmulator", self)
    self.lovechild:SetPos(2, 23)
    BaseClass.Init(self)
    
end

function PANEL:SetLoveInstance(love)
    self.lovechild:SetLoveInstance(love)
end

function PANEL:SetWindowSize(w, h)
    self.lovechild:SetSize(w, h)
    self:SetSize(w + 4, h + 23)
end

function PANEL:PerformLayout()
    BaseClass.PerformLayout(self)
end

vgui.Register("VGUILove", PANEL, "DFrame")
]]