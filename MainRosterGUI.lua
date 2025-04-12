local AceGUI = LibStub("AceGUI-3.0")
local RosterMainFrame = ObisLootAddon.Interface.RosterMainFrame


local function ChangeRosterPlayer(widget, _, value)
    local player = widget:GetUserData("player")
    ObisLootAddonDB.MainRoster[player.guid].isMain = value
end


---@param player player
---@return AceGUISimpleGroup
local function CreatePlayerGroup(player)
    local group = AceGUI:Create("SimpleGroup") --[[@as AceGUISimpleGroup]]
    local checkbox = AceGUI:Create("CheckBox") --[[@as AceGUICheckBox]]
    checkbox:SetLabel(player:GetColoredName())
    checkbox:SetUserData("player", player)
    checkbox:SetCallback("OnValueChanged", ChangeRosterPlayer)
    checkbox:SetValue(player.isMain)
    group:AddChild(checkbox)
    return group
end


function ObisLootAddon:CreateRosterMainFrame()
    local frame = AceGUI:Create("Frame") --[[@as AceGUIFrame]]
    frame:SetTitle("Mains")
    for _, player in pairs(ObisLootAddonDB.MainRoster) do
        player = ObisLootAddon:GetPlayer(player.guid)
        frame:AddChild(CreatePlayerGroup(player))
    end
    return frame
end

function ObisLootAddon:ToggleRosterMainFrame()
    if not RosterMainFrame or not RosterMainFrame:IsShown() then
        RosterMainFrame = ObisLootAddon:CreateRosterMainFrame()
    else
        RosterMainFrame:Hide()
    end
end