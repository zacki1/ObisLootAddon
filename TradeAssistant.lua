--- TradeAssistant.lua - Trade automation: range check, initiate trade, place item, track status.
--- Does NOT auto-accept trades (protected API).

---Resolve a player name to a raid unit token ("raid1", "raid2", etc.)
---@param name string
---@return string?
local function GetUnitTokenByName(name)
    for i = 1, 40 do
        local unitToken = "raid" .. i
        if Ambiguate(UnitName(unitToken) or "", "none") == name then return unitToken end
    end
    return nil
end

---Find an item in the player's bags by item link
---@param itemLink string
---@return integer? bag, integer? slot
function ObisLootAddon:FindItemInBags(itemLink)
    for bag = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink == itemLink then
                return bag, slot
            end
        end
    end
    return nil, nil
end

---Check if a player is in trade range by name
---@param playerName string
---@return boolean
function ObisLootAddon:IsInTradeRange(playerName)
    local unit = GetUnitTokenByName(playerName)
    if not unit then return false end
    return CheckInteractDistance(unit, 2) and true or false
end

---Start trading with a winner: open trade window and place item
---@param winnerName string
---@param itemLink string
function ObisLootAddon:StartTrade(winnerName, itemLink)
    if not self:IsManager() then
        self:Print("Nur Manager können Trades starten.")
        return
    end

    local unit = GetUnitTokenByName(winnerName)
    if not unit then
        self:Print(winnerName .. " nicht im Raid gefunden!")
        return
    end

    if not CheckInteractDistance(unit, 2) then
        self:Print(winnerName .. " ist nicht in Reichweite!")
        return
    end

    -- Store pending trade info
    self.pendingTrade = {
        winnerName = winnerName,
        itemLink = itemLink,
    }

    InitiateTrade(unit)
end

---Place the pending trade item into the trade window (called after TRADE_SHOW)
function ObisLootAddon:PlaceTradeItem()
    if not self.pendingTrade then return end

    local bag, slot = self:FindItemInBags(self.pendingTrade.itemLink)
    if bag and slot then
        C_Container.PickupContainerItem(bag, slot)
        ClickTradeButton(1)
        self:Print("Item in Handelsfenster gelegt: " .. self.pendingTrade.itemLink)
    else
        self:Print("Item nicht in Taschen gefunden: " .. self.pendingTrade.itemLink)
    end
end

---Mark an item as traded to a specific winner
---@param itemLink string
---@param winnerGuid string
function ObisLootAddon:MarkAsTraded(itemLink, winnerGuid)
    local itemData = self.currentId.items[itemLink]
    if not itemData then return end

    if not itemData.traded then itemData.traded = {} end
    itemData.traded[winnerGuid] = date("%Y-%m-%d %H:%M")
    self:SaveId()
    self:Print("Handel abgeschlossen für " .. itemLink)
end

---Check if an item has been traded to a winner
---@param itemLink string
---@param winnerGuid string
---@return boolean
function ObisLootAddon:IsTraded(itemLink, winnerGuid)
    local itemData = self.currentId.items[itemLink]
    if not itemData or not itemData.traded then return false end
    return itemData.traded[winnerGuid] ~= nil
end

-- Trade events
function ObisLootAddon:TRADE_SHOW()
    self:PlaceTradeItem()
end

---Track successful trade completion via system message
function ObisLootAddon:UI_INFO_MESSAGE(_, _, msg)
    ---@diagnostic disable-next-line: undefined-global
    if msg == ERR_TRADE_COMPLETE and self.pendingTrade then
        local trade = self.pendingTrade
        -- Find winner guid from current items
        for _, item in pairs(self.currentId.items) do
            for _, winner in pairs(item.gewinner) do
                if winner.player.name == trade.winnerName then
                    self:MarkAsTraded(trade.itemLink, winner.player.guid)
                    return
                end
            end
        end
    end
end

function ObisLootAddon:TRADE_CLOSED()
    self.pendingTrade = nil
end
