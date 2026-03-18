local AceGUI = LibStub("AceGUI-3.0")
local MainFrame = ObisLootAddon.Interface.MainFrame


function ObisLootAddon:CreateMainFrame()
	local frame = AceGUI:Create("Frame") --[[@as AceGUIFrame]]
	frame:SetCallback("OnClose", function (widget) AceGUI:Release(widget) end)
	frame:SetTitle("Obis Loot Addon")
	frame:SetLayout("Flow")
	frame:SetStatusText("")
---@diagnostic disable-next-line: invisible
	frame.statustext:GetParent():Hide()
	return frame
end
---Create a list of items — shows roll button for unresolved, winner info for resolved
---@param id id
---@return AceGUIContainer
function ObisLootAddon:CreateItemList(id)
	local scroll = AceGUI:Create("ScrollFrame") --[[@as AceGUIScrollFrame]]
	scroll:SetLayout("Flow")
	scroll:SetFullWidth(true)
	scroll:SetFullHeight(true)
	for itemLink, data in pairs(id.items) do
		if #data.gewinner > 0 then
			for _, winner in pairs(data.gewinner) do
				scroll:AddChild(self:CreateItemListItem(itemLink, winner))
			end
		else
			scroll:AddChild(self:CreateUnresolvedItem(itemLink, data))
		end
	end
	return scroll
end

local function ChangeWinner(widget, event, index)
	local item = widget:GetUserData("item")
	local gewinner = widget:GetUserData("winner")
	for _, winner in pairs(ObisLootAddonDB.Ids[0].items[item].gewinner) do
		if winner.player.guid == gewinner.player.guid then
			winner.player = ObisLootAddon:GetPlayer(widget.list[index])
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
	itemText:SetImage(item:GetItemIcon() --[[@as number]])
	itemText:SetText(itemLink)
	itemText:SetFullHeight(false)
	itemText:SetCallback("OnEnter", function (widget)
---@diagnostic disable-next-line: invisible
		GameTooltip:SetOwner(itemText.frame, "ANCHOR_TOP")
		GameTooltip:SetHyperlink(itemLink)
		GameTooltip:Show()
	end
	)
	itemText:SetCallback("OnLeave", function (widget)
		GameTooltip:Hide()
	end)
	local playerText = AceGUI:Create("Dropdown")--[[@as AceGUIDropdown]]
	local player = ObisLootAddon:GetPlayer(gewinner.player.guid)
	local names = ObisLootAddon:GetMemberNamesOfCurrentId()
	playerText:SetLabel("Gewinner: ")
	playerText:SetUserData("item", itemLink)
	playerText:SetUserData("winner", gewinner)
	playerText:SetText(player:GetColoredName())
	playerText:SetList(names)
	playerText:SetCallback("OnValueChanged", ChangeWinner)
	if not ObisLootAddon:IsManager() then
		playerText:SetDisabled(true)
	end

	-- Dynamic pullout height: fits entries but never exceeds main frame
---@diagnostic disable-next-line: invisible, undefined-field
	playerText.button:HookScript("OnClick", function()
---@diagnostic disable-next-line: undefined-field
		if playerText.pullout then
			local listHeight = #names * 20 + 16
---@diagnostic disable-next-line: invisible
			local frameHeight = MainFrame.frame:GetHeight()
---@diagnostic disable-next-line: undefined-field
			playerText.pullout:SetMaxHeight(math.min(listHeight, frameHeight))
		end
	end)

	local button = AceGUI:Create("Button")--[[@as AceGUIButton]]
	button:SetText("Rolls ausgeben")
	button:SetCallback("OnClick", function() ObisLootAddon:PrintListInChat(itemLink) end)
	if not ObisLootAddon:IsManager() then
---@diagnostic disable-next-line: invisible
		button.frame:Hide()
	end

	group:AddChild(itemText)
	group:AddChild(playerText)
	group:AddChild(button)

	-- Trade controls (manager only)
	if ObisLootAddon:IsManager() then
		local traded = ObisLootAddon:IsTraded(itemLink, gewinner.player.guid)

		if traded then
			local tradedLabel = AceGUI:Create("Label")--[[@as AceGUILabel]]
			tradedLabel:SetText("|cff00ff00Gehandelt|r")
			tradedLabel:SetRelativeWidth(0.33)
			group:AddChild(tradedLabel)
		else
			local tradeButton = AceGUI:Create("Button")--[[@as AceGUIButton]]
			local winnerName = gewinner.player.name

			-- Update range indicator on a ticker
			local function UpdateRangeText()
				local inRange = ObisLootAddon:IsInTradeRange(winnerName)
				if inRange then
					tradeButton:SetText("|cff00ff00●|r Handeln")
				else
					tradeButton:SetText("|cffff0000●|r Handeln")
				end
			end
			UpdateRangeText()

			tradeButton:SetRelativeWidth(0.33)
			tradeButton:SetCallback("OnClick", function()
				ObisLootAddon:StartTrade(winnerName, itemLink)
			end)
			group:AddChild(tradeButton)

			-- Range ticker: update every 2 seconds, cancel on release
			local ticker = C_Timer.NewTicker(2, function()
---@diagnostic disable-next-line: invisible
				if group.frame and group.frame:IsShown() then
					UpdateRangeText()
				end
			end)
			group:SetCallback("OnRelease", function()
				ticker:Cancel()
			end)
		end
	end

	return group
end


---Creates a group for an item that has no winner yet (pending or rolling)
---@param itemLink string
---@param data itemRoll
---@return AceGUISimpleGroup
function ObisLootAddon:CreateUnresolvedItem(itemLink, data)
	local group = AceGUI:Create("SimpleGroup") --[[@as AceGUISimpleGroup]]
	local item = Item:CreateFromItemLink(itemLink)
	group:SetRelativeWidth(1)
	group:SetLayout("Flow")

	local itemText = AceGUI:Create("InteractiveLabel") --[[@as AceGUIInteractiveLabel]]
	itemText:SetRelativeWidth(0.5)
	itemText:SetImage(item:GetItemIcon() --[[@as number]])
	itemText:SetText(itemLink .. (data.count > 1 and " x" .. data.count or ""))
	itemText:SetCallback("OnEnter", function()
---@diagnostic disable-next-line: invisible
		GameTooltip:SetOwner(itemText.frame, "ANCHOR_TOP")
		GameTooltip:SetHyperlink(itemLink)
		GameTooltip:Show()
	end)
	itemText:SetCallback("OnLeave", function()
		GameTooltip:Hide()
	end)
	group:AddChild(itemText)

	if ObisLootAddon:IsManager() then
		local isRolling = self.currentItem == itemLink
		if isRolling then
			local label = AceGUI:Create("Label") --[[@as AceGUILabel]]
			label:SetText("|cffffcc00Würfeln läuft...|r")
			label:SetRelativeWidth(0.5)
			group:AddChild(label)
		else
			local rollBtn = AceGUI:Create("Button") --[[@as AceGUIButton]]
			rollBtn:SetText("Roll starten")
			rollBtn:SetRelativeWidth(0.5)
			rollBtn:SetCallback("OnClick", function()
				self.currentItem = itemLink
				self.currentId.items[itemLink].rolls = {}
				SendChatMessage("Gewürfelt wird für: " .. itemLink, "RAID")
				self:UpdateRollDisplay()
				self:RegisterEvent("CHAT_MSG_SYSTEM")
			end)
			group:AddChild(rollBtn)
		end
	else
		local label = AceGUI:Create("Label") --[[@as AceGUILabel]]
		if self.currentItem == itemLink then
			label:SetText("|cffffcc00Würfeln läuft...|r")
		else
			label:SetText("Warte auf Roll...")
		end
		label:SetRelativeWidth(0.5)
		group:AddChild(label)
	end

	return group
end

function ObisLootAddon:ToggleMainFrame()
    if not MainFrame or not MainFrame:IsShown() then
        MainFrame = ObisLootAddon:CreateMainFrame()

        -- Raid history selector
        local historyDropdown = AceGUI:Create("Dropdown")--[[@as AceGUIDropdown]]
        historyDropdown:SetLabel("Raid:")
        historyDropdown:SetRelativeWidth(1)

        local historyList = {}
        local historyOrder = {}
        -- Current raid first
        if self.currentId.raidId then
            historyList[self.currentId.raidId] = self.currentId.raidId .. " (aktuell)"
            table.insert(historyOrder, self.currentId.raidId)
        end
        -- Past raids
        for raidId, _ in pairs(ObisLootAddonDB.History or {}) do
            if raidId ~= (self.currentId.raidId or "") then
                historyList[raidId] = raidId
                table.insert(historyOrder, raidId)
            end
        end

        historyDropdown:SetList(historyList, historyOrder)
        if self.currentId.raidId then
            historyDropdown:SetValue(self.currentId.raidId)
        end

        local contentScroll

        historyDropdown:SetCallback("OnValueChanged", function(_, _, raidId)
            local id = ObisLootAddonDB.History[raidId] or self.currentId
            if contentScroll then contentScroll:Release() end
            contentScroll = self:CreateItemList(id)
            MainFrame:AddChild(contentScroll)
        end)

        MainFrame:AddChild(historyDropdown)

        if ObisLootAddonDB.Ids[0] then
            contentScroll = self:CreateItemList(ObisLootAddonDB.Ids[0])
            MainFrame:AddChild(contentScroll)
        end
    else
        MainFrame:Release()
    end
end