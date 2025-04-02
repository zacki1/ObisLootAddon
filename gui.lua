local AceGUI = LibStub("AceGUI-3.0")
local MainFrame = ObisLootAddon.Interface.MainFrame
local classcolor = {
	DEATHKNIGHT	= "C41E3A",
	DEMONHUNTER	= "A330C9",
	DRUID		= "FF7C0A",
    EVOKER      = "33937F",
	HUNTER		= "AAD372",
	MAGE		= "3FC7EB",
	MONK		= "00FF98",
	PALADIN		= "F48CBA",
	PRIEST		= "FFFFFF",
	ROGUE		= "FFF468",
	SHAMAN		= "0070DD",
	WARLOCK		= "8788EE",
	WARRIOR		= "C69B6D",
}

function ObisLootAddon:CreateMainFrame()
	local frame = AceGUI:Create("Frame") --[[@as AceGUIFrame]]
	frame:SetCallback("OnClose", function (widget) AceGUI:Release(widget) end)
	frame:SetTitle("Obis Loot Addon")
	frame:SetLayout("Fill")
	return frame
end
---Create a list of items and their winners in a scrollframe
---@param id id
---@return AceGUIContainer
function ObisLootAddon:CreateItemList(id)
	local scroll = AceGUI:Create("ScrollFrame") --[[@as AceGUIScrollFrame]]
	scroll:SetLayout("Flow")
	scroll:SetFullWidth(true)
	scroll:SetFullHeight(true)
    for item, data in pairs(id.items) do
		for _, winner in pairs(data.gewinner) do
			scroll:AddChild(ObisLootAddon:CreateItemListItem(item, winner))
		end
    end
	return scroll
end

local function ChangeWinner(widget, event, index)
	local item = widget:GetUserData("item")
	local gewinner = widget:GetUserData("winner")
	for _, winner in pairs(ObisLootAddonDB.Ids[0][item].gewinner) do
		if winner.player == gewinner.player then
			winner.player = widget.list[index]
		end
	end
end

---Creates a group widget with the item and the winner
---@param itemLink string
---@param gewinner roll
---@return AceGUISimpleGroup
function ObisLootAddon:CreateItemListItem(itemLink, gewinner)
	local group = AceGUI:Create("SimpleGroup") --[[@as AceGUISimpleGroup]]
	local item = Item:CreateFromItemLink(itemLink)
	local itemText = AceGUI:Create("InteractiveLabel") --[[@as AceGUIInteractiveLabel]]
	group:SetRelativeWidth(1)
	group:SetLayout("Flow")
	itemText:SetRelativeWidth(0.33)
	itemText:SetImage(item:GetItemIcon())
	itemText:SetText(itemLink)
	itemText:SetFullHeight(false)
	itemText:SetCallback("OnEnter", function (widget)
		GameTooltip:SetOwner(itemText.label, "ANCHOR_TOP")
		GameTooltip:SetHyperlink(itemLink)
		GameTooltip:Show()
	end
	)
	itemText:SetCallback("OnLeave", function (widget)
		GameTooltip:Hide()
	end)
	local playerText = AceGUI:Create("Dropdown")--[[@as AceGUIDropdown]]
	playerText:SetLabel("Gewinner: ")
	playerText:SetUserData("item", itemLink)
	playerText:SetUserData("winner", gewinner)
	playerText:SetText(gewinner.player)
	playerText:SetList(ObisLootAddon:GetRaidMembers())
	playerText:SetCallback("OnValueChanged", ChangeWinner)
	group:AddChild(itemText)
	group:AddChild(playerText)
	return group
end


function ObisLootAddon:ToggleMainFrame()
    if not MainFrame or not MainFrame:IsShown() then
        MainFrame = ObisLootAddon:CreateMainFrame()
		if not ObisLootAddonDB.Ids[0] then return end
		MainFrame:AddChild(ObisLootAddon:CreateItemList(ObisLootAddonDB.Ids[0]))
    else
        MainFrame:Hide()
    end
end