love = include "loveemu.lua"

include "panel_love.lua"
include "main_love.lua"

if (IsValid(GBPanel)) then
    GBPanel:Remove()
end
GBPanel = vgui.Create("VGUILove", nil, "LuaGB")
GBPanel:SetLoveInstance(love)
GBPanel:MakePopup()