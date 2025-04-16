local AceGUI = LibStub("AceGUI-3.0")
local RosterMainFrame = ObisLootAddon.Interface.RosterMainFrame
local private = select(2, ...)

local function ChangeRosterPlayer(widget, _, value)
    local player = widget:GetUserData("player")
    ObisLootAddonDB.MainRoster[player.guid].isMain = value
end

local function GetSortedRoster()
    local sortedList = {}
    for _, player in pairs(ObisLootAddonDB.MainRoster) do
        table.insert(sortedList, player)
    end

    table.sort(sortedList, private.SortRoster)

    return sortedList
end

---@param player player
---@return AceGUISimpleGroup
local function CreatePlayerGroup(player)
    local group = AceGUI:Create("SimpleGroup") --[[@as AceGUISimpleGroup]]
    group:SetLayout("Flow")
    group:SetWidth(200)
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
    frame:SetLayout("Fill")
    frame:SetTitle("Mains")
    frame:SetCallback("OnClose", function (widget) AceGUI:Release(widget) end)
    local scroll = AceGUI:Create("ScrollFrame")--[[@as AceGUIScrollFrame]]
    scroll:SetLayout("Flow")
    for _, player in pairs(GetSortedRoster()) do
        player = ObisLootAddon:GetPlayer(player.guid)
        scroll:AddChild(CreatePlayerGroup(player))
    end
    frame:AddChild(scroll)
    return frame
end

function ObisLootAddon:ToggleRosterMainFrame()
    if not RosterMainFrame or not RosterMainFrame:IsShown() then
        RosterMainFrame = ObisLootAddon:CreateRosterMainFrame()
    else
        RosterMainFrame:Release()
    end
end