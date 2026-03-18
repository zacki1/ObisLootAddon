# New Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add loot detection, trade assistant, debug mode, permissions, and per-raid history to ObisLootAddon.

**Architecture:** Each feature is a self-contained module following the existing Core/Events/UI separation. Pure logic goes in Core.lua, WoW API integration in Events.lua or new event files, UI in dedicated per-window files. Trade logic gets its own TradeAssistant.lua since it manages its own events and state.

**Tech Stack:** Lua, Ace3 (AceGUI-3.0, AceDB-3.0, AceEvent-3.0), WoW Retail 12.x API

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `classes.lua` | Modify | Add new type annotations (tradeState, raidHistory) |
| `Core.lua` | Modify | Add loot quality filtering, bag scanning logic |
| `ObisLoot.lua` | Modify | Add permission state, history DB structure |
| `Events.lua` | Modify | Add LOOT_OPENED handler, permission checks |
| `TradeAssistant.lua` | Create | Trade window automation, range checking, trade tracking |
| `DebugMode.lua` | Create | `/obis debug` command, dummy loot simulation |
| `gui.lua` | Modify | Add traded status indicator, permission-based visibility |
| `liverolls.lua` | Modify | Permission-based button visibility |
| `ObisLootAddon.toc` | Modify | Add new files to load order |
| `tests.lua` | Modify | Add tests for new Core.lua functions |

---

## Task 1: Loot Detection (START_LOOT_ROLL)

Detect all boss loot the moment it drops via `START_LOOT_ROLL`. This fires once per item when Group Loot presents the Need/Greed/Pass window — giving the addon the complete loot table instantly, before anyone rolls or passes.

**Files:**
- Modify: `Core.lua` — add `Core.IsLootRelevant(quality, threshold)`
- Modify: `Events.lua` — add `START_LOOT_ROLL` handler
- Modify: `ObisLoot.lua:44-46` — register event
- Modify: `tests.lua` — add tests for `IsLootRelevant`

### Steps

- [ ] **Step 1: Write failing test for IsLootRelevant**

In `tests.lua`, add after the IsRerollEligible section:

```lua
-- ===================== IsLootRelevant =====================
print("\n=== IsLootRelevant ===")

test("epic quality is relevant at default threshold", function()
    assertTrue(Core.IsLootRelevant(4, 4))  -- 4 = Epic
end)

test("rare quality is not relevant at epic threshold", function()
    assertFalse(Core.IsLootRelevant(3, 4))  -- 3 = Rare
end)

test("legendary quality is relevant at epic threshold", function()
    assertTrue(Core.IsLootRelevant(5, 4))  -- 5 = Legendary
end)

test("nil quality returns false", function()
    assertFalse(Core.IsLootRelevant(nil, 4))
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua tests.lua`
Expected: FAIL — `IsLootRelevant` not defined

- [ ] **Step 3: Implement IsLootRelevant in Core.lua**

Add before the `-- Attach to addon` section in `Core.lua`:

```lua
---Check if a loot item meets the quality threshold
---@param quality integer? Item quality (0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic, 5=Legendary)
---@param threshold integer Minimum quality to consider relevant
---@return boolean
function Core.IsLootRelevant(quality, threshold)
    if not quality then return false end
    return quality >= threshold
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua tests.lua`
Expected: All tests PASS

- [ ] **Step 5: Add START_LOOT_ROLL handler in Events.lua**

Add after the `CHAT_MSG_RAID_LEADER` function.
Fires once per item when Group Loot generates a roll window after a boss kill.
`GetLootRollItemInfo(rollID)` returns full item details including link and quality.

```lua
---Detect epic+ items from boss loot the moment they drop
---@param _ string event name (from AceEvent)
---@param rollID integer The loot roll ID
function ObisLootAddon:START_LOOT_ROLL(_, rollID)
    if not IsInRaid() then return end

    local _, _, _, quality, _, _, _, _, _, _, _, _, _, _, itemLink = GetLootRollItemInfo(rollID)
    if not itemLink then return end
    if not Core.IsLootRelevant(quality, 4) then return end

    -- Register the item for rolling (skip if already tracked)
    if not self.currentId.items[itemLink] then
        self.currentId.items[itemLink] = { count = 1, gewinner = {}, rolls = {} }
        self:Print("Boss-Loot erkannt: " .. itemLink)
    else
        -- Same item dropped multiple times
        self.currentId.items[itemLink].count = self.currentId.items[itemLink].count + 1
        self:Print("Boss-Loot erkannt: " .. itemLink .. " x" .. self.currentId.items[itemLink].count)
    end
end
```

- [ ] **Step 6: Register START_LOOT_ROLL in OnInitialize**

In `ObisLoot.lua`, add to the `OnInitialize` function after the existing RegisterEvent calls:

```lua
    self:RegisterEvent("START_LOOT_ROLL")
```

- [ ] **Step 7: Update CreateItemList in gui.lua to show all items**

Currently `CreateItemList` only shows items that have winners. Change it to show every tracked item, with different controls based on state.

Replace the `CreateItemList` function:

```lua
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
			-- Resolved: show each winner
			for _, winner in pairs(data.gewinner) do
				scroll:AddChild(self:CreateItemListItem(itemLink, winner))
			end
		else
			-- Unresolved: show item with roll controls
			scroll:AddChild(self:CreateUnresolvedItem(itemLink, data))
		end
	end
	return scroll
end
```

- [ ] **Step 8: Add CreateUnresolvedItem in gui.lua**

Add a new function for items that have no winner yet. Shows the item icon/link and a state-dependent button:

```lua
---Creates a group for an item that has no winner yet (pending or rolling)
---@param itemLink string
---@param data itemRoll
---@return AceGUISimpleGroup
function ObisLootAddon:CreateUnresolvedItem(itemLink, data)
	local group = AceGUI:Create("SimpleGroup") --[[@as AceGUISimpleGroup]]
	local item = Item:CreateFromItemLink(itemLink)
	group:SetRelativeWidth(1)
	group:SetLayout("Flow")

	-- Item icon + link
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

	-- State-dependent controls (manager only)
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
		-- Viewers see status only
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
```

- [ ] **Step 9: Commit**

```bash
git add Core.lua Events.lua ObisLoot.lua gui.lua tests.lua
git commit -m "feat: auto-detect boss loot via START_LOOT_ROLL with roll UI"
```

---

## Task 2: Permissions (Manager vs Viewer)

Managers (Leader/Assist) get full access. Viewers get roll buttons only and read-only history.

**Files:**
- Modify: `Core.lua` — add `Core.IsManager(raidRank)`
- Modify: `Events.lua` — add permission check helper, gate commands
- Modify: `liverolls.lua` — hide "Würfeln beenden" for viewers
- Modify: `gui.lua` — disable winner dropdown and buttons for viewers
- Modify: `tests.lua` — add tests for `IsManager`

### Steps

- [ ] **Step 1: Write failing test for IsManager**

In `tests.lua`:

```lua
-- ===================== IsManager =====================
print("\n=== IsManager ===")

test("rank 2 (leader) is manager", function()
    assertTrue(Core.IsManager(2))
end)

test("rank 1 (assist) is manager", function()
    assertTrue(Core.IsManager(1))
end)

test("rank 0 (member) is not manager", function()
    assertFalse(Core.IsManager(0))
end)

test("nil rank is not manager", function()
    assertFalse(Core.IsManager(nil))
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `lua tests.lua`
Expected: FAIL

- [ ] **Step 3: Implement IsManager in Core.lua**

```lua
---Check if a player's raid rank grants manager permissions
---@param raidRank integer? 0=member, 1=assist, 2=leader
---@return boolean
function Core.IsManager(raidRank)
    if not raidRank then return false end
    return raidRank >= 1
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `lua tests.lua`
Expected: All PASS

- [ ] **Step 5: Add permission helper and expose it in Events.lua**

Add near the top of Events.lua, after the local variables:

```lua
---Resolve the current player's name for raid roster comparison
local myName = nil

---Check if the current player is a raid manager (leader or assist)
---@return boolean
local function IsPlayerManager()
    if not myName then myName = UnitName("player") end
    for i = 1, 40 do
        local name, rank = GetRaidRosterInfo(i)
        if name and Ambiguate(name, "none") == myName then
            return Core.IsManager(rank)
        end
    end
    return false
end

---Public permission check for UI files
---@return boolean
function ObisLootAddon:IsManager()
    return IsPlayerManager()
end
```

- [ ] **Step 6: Gate slash commands behind permission check**

In the `Commands` function in Events.lua, add at the top before the if/elseif chain.
Viewers are allowed `roll` and `dump` (read-only):

```lua
    local isManager = IsPlayerManager()
    local viewerAllowed = { roll = true, dump = true }
    if not isManager and not viewerAllowed[cmd] then
        ObisLootAddon:Print("Nur Raidleiter und Assists können diesen Befehl nutzen.")
        return
    end
```

- [ ] **Step 7: Gate "Würfeln beenden" button in liverolls.lua**

In `liverolls.lua`, wrap the actionButton creation to only show for managers.
Note: `ObisLootAddon:IsManager()` is already defined from Step 5 (Events.lua loads before liverolls.lua in TOC).

Replace the actionButton block with:

```lua
    local actionButton = AceGUI:Create("Button")--[[@as AceGUIButton]]
    actionButton:SetText("Würfeln beenden")
    actionButton:SetCallback("OnClick", function()
            ObisLootAddon:UnregisterEvent("CHAT_MSG_SYSTEM")
            ObisLootAddon:ErgebnisseAusgeben()
            ObisLootAddon:SaveId()
            ObisLootAddon.currentItem = nil
            RollFrame:Release()
    end)
    actionButton:SetHeight(20)
    actionButton:SetWidth(140)
    actionButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 17, 17)

    -- Only show stop button for managers
    if not ObisLootAddon:IsManager() then
---@diagnostic disable-next-line: invisible
        actionButton.frame:Hide()
    end

    RollFrame:AddChild(actionButton)
```

- [ ] **Step 9: Disable winner dropdown for viewers in gui.lua**

In `gui.lua`, after `playerText:SetCallback("OnValueChanged", ChangeWinner)`, add:

```lua
	if not ObisLootAddon:IsManager() then
		playerText:SetDisabled(true)
	end
```

And for the "Rolls ausgeben" button, after its creation:

```lua
	if not ObisLootAddon:IsManager() then
---@diagnostic disable-next-line: invisible
		button.frame:Hide()
	end
```

- [ ] **Step 10: Commit**

```bash
git add Core.lua Events.lua liverolls.lua gui.lua tests.lua
git commit -m "feat: add manager/viewer permissions based on raid rank"
```

---

## Task 3: Per-Raid History

Store history per raid lockout instead of always overwriting ID 0. Each raid gets a unique ID based on instance + date.

**Files:**
- Modify: `classes.lua` — add raidHistory type
- Modify: `ObisLoot.lua` — change ID management, add history init
- Modify: `Events.lua` — generate raid IDs on GROUP_ROSTER_UPDATE
- Modify: `gui.lua` — add raid selector dropdown to main frame

### Steps

- [ ] **Step 1: Add type annotations in classes.lua**

Add to `classes.lua`:

```lua
---@class raidHistory
---@field raidId string
---@field zone string
---@field difficulty string
---@field date string
---@field items itemDict
---@field roster roster
```

- [ ] **Step 2: Update OnInitialize in ObisLoot.lua**

Replace the currentId initialization logic in `OnInitialize`:

```lua
function ObisLootAddon:OnInitialize()
    if not ObisLootAddonDB then ObisLootAddonDB = {} end
    if not ObisLootAddonDB.Ids then ObisLootAddonDB.Ids = {} end
    if not ObisLootAddonDB.MainRoster then ObisLootAddonDB.MainRoster = {} end
    if not ObisLootAddonDB.History then ObisLootAddonDB.History = {} end
    self.currentId = ObisLootAddonDB.Ids[0] or self.currentId
    self:LoadMinimap()
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("CHAT_MSG_RAID")
    self:RegisterEvent("CHAT_MSG_RAID_LEADER")
    self:RegisterEvent("START_LOOT_ROLL")
end
```

- [ ] **Step 3: Add raid ID generation in Events.lua**

Add a function to generate or resume a raid ID:

```lua
---Generate a unique raid ID from instance info and date
---@return string? raidId, string? zone, string? difficultyName, string? dateStr
local function GetOrCreateRaidId()
    local zone, _, difficultyIndex, difficultyName = ObisLootAddon:GetInstanceInformation()
    if not zone then return nil end
    local dateStr = date("%Y-%m-%d")
    local raidId = zone .. "-" .. difficultyIndex .. "-" .. dateStr
    return raidId, zone, difficultyName, dateStr
end
```

- [ ] **Step 4: Update GROUP_ROSTER_UPDATE to manage raid IDs**

Replace the `GROUP_ROSTER_UPDATE` handler:

```lua
function ObisLootAddon:GROUP_ROSTER_UPDATE()
    if not IsInRaid() then return end
    local _, _, difficultyIndex = GetInstanceInfo()
    if difficultyIndex == 7 or difficultyIndex == 17 then return end

    -- Create or resume raid ID
    local raidId, zone, difficultyName, dateStr = GetOrCreateRaidId()
    if raidId and self.currentId.raidId ~= raidId then
        -- Save current if it has data
        if self.currentId.raidId then
            ObisLootAddonDB.History[self.currentId.raidId] = self.currentId
        end
        -- Resume existing or create new
        if ObisLootAddonDB.History[raidId] then
            self.currentId = ObisLootAddonDB.History[raidId]
        else
            self.currentId = {
                id = 0,
                raidId = raidId,
                zone = zone,
                difficulty = difficultyName,
                date = dateStr,
                items = {},
                rerollArchive = {},
                roster = {},
            }
        end
        ObisLootAddonDB.Ids[0] = self.currentId
    end

    local memberList = self:GetRaidMembers()
    for _, member in pairs(memberList) do
        self:AddToMainRoster(member)
        self:AddToCurrentId(member)
    end
end
```

- [ ] **Step 5: Add raid history selector to gui.lua**

Update `ToggleMainFrame` to include a dropdown for selecting past raids:

```lua
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
        for raidId, data in pairs(ObisLootAddonDB.History or {}) do
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
            if contentScroll then contentScroll:ReleaseChildren() end
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
```

Note: The main frame layout needs to change from `"Fill"` to `"Flow"` to accommodate the dropdown above the scroll list.

In `CreateMainFrame`, change:

```lua
    frame:SetLayout("Flow")
```

- [ ] **Step 6: Update SaveId to persist to history**

In `ObisLoot.lua`, update `SaveId`:

```lua
function ObisLootAddon:SaveId()
    ObisLootAddonDB.Ids[self.currentId.id] = self.currentId
    if self.currentId.raidId then
        ObisLootAddonDB.History[self.currentId.raidId] = self.currentId
    end
end
```

- [ ] **Step 7: Commit**

```bash
git add classes.lua ObisLoot.lua Events.lua gui.lua
git commit -m "feat: store loot history per raid lockout with raid selector in UI"
```

---

## Task 4: Trade Assistant

Automate the trade workflow: check range, open trade, place item, track completion.

**Files:**
- Create: `TradeAssistant.lua` — trade logic and event handling
- Create: `TradeGUI.lua` — trade UI per winner in gui.lua
- Modify: `classes.lua` — add trade tracking fields
- Modify: `gui.lua` — integrate trade buttons into item list
- Modify: `ObisLootAddon.toc` — add new files

### Steps

- [ ] **Step 1: Add trade tracking type in classes.lua**

```lua
---@class tradeInfo
---@field itemLink string
---@field winnerGuid string
---@field traded boolean
---@field tradedAt string?
```

Add `traded` field to the `itemRoll` class:

```lua
---@class itemRoll
---@field count integer
---@field rolls roll[]
---@field gewinner roll[]
---@field traded boolean[]?
```

- [ ] **Step 2: Create TradeAssistant.lua**

```lua
--- TradeAssistant.lua - Trade automation: range check, initiate trade, place item, track status.
--- Does NOT auto-accept trades (protected API).

---Resolve a player name to a raid unit token ("raid1", "raid2", etc.)
---@param name string
---@return string?
local function GetUnitTokenByName(name)
    for i = 1, 40 do
        local unitToken = "raid" .. i
        if UnitName(unitToken) == name then return unitToken end
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
```

- [ ] **Step 3: Register trade events in ObisLoot.lua**

In `OnInitialize`, add:

```lua
    self:RegisterEvent("TRADE_SHOW")
    self:RegisterEvent("UI_INFO_MESSAGE")
    self:RegisterEvent("TRADE_CLOSED")
```

- [ ] **Step 4: Add trade UI to gui.lua**

In `CreateItemListItem`, after the "Rolls ausgeben" button, add trade controls for each winner:

```lua
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
```

- [ ] **Step 5: Update TOC to include TradeAssistant.lua**

In `ObisLootAddon.toc`, add after `Events.lua`:

```
TradeAssistant.lua
```

- [ ] **Step 6: Commit**

```bash
git add classes.lua TradeAssistant.lua gui.lua ObisLoot.lua ObisLootAddon.toc
git commit -m "feat: trade assistant with range check, auto-place item, and trade tracking"
```

---

## Task 5: Debug Mode

Add `/ola debug` subcommand to simulate loot drops with dummy data for testing UI and logic without killing a boss. Replaces the existing `/obistest` slash command. Debug commands are gated behind manager permissions (from Task 2).

**Files:**
- Create: `DebugMode.lua` — debug simulation functions
- Modify: `Events.lua` — add `debug` to the `/ola` command handler
- Modify: `ObisLootAddon.toc` — add DebugMode.lua
- Modify: `liverolls.lua` — remove old `/obistest` command

### Steps

- [ ] **Step 1: Create DebugMode.lua**

```lua
--- DebugMode.lua - Simulate loot drops and rolls for testing without a raid.
--- Called via /ola debug loot|draw (manager-only, gated in Events.lua).

local Core = ObisLootAddon.Core

local DUMMY_PLAYERS = {
    { name = "Tankadin", class = "PALADIN", guid = "Player-0000-DEBUG01", realm = "DebugRealm", isMain = true },
    { name = "Healpriest", class = "PRIEST", guid = "Player-0000-DEBUG02", realm = "DebugRealm", isMain = true },
    { name = "Shadowmage", class = "MAGE", guid = "Player-0000-DEBUG03", realm = "DebugRealm", isMain = true },
    { name = "Furywarrior", class = "WARRIOR", guid = "Player-0000-DEBUG04", realm = "DebugRealm", isMain = false },
    { name = "Restodruid", class = "DRUID", guid = "Player-0000-DEBUG05", realm = "DebugRealm", isMain = true },
}

local DUMMY_ITEMS = {
    "|cffa335ee|Hitem:19019::::::::60:::::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r",
    "|cffa335ee|Hitem:17182::::::::60:::::::|h[Sulfuras, Hand of Ragnaros]|h|r",
    "|cffa335ee|Hitem:18803::::::::60:::::::|h[Finkle's Lava Dredger]|h|r",
}

---Add GetColoredName method to dummy players
local function PrepareDummyPlayers()
    for _, p in ipairs(DUMMY_PLAYERS) do
        p.GetColoredName = function(self)
            return RAID_CLASS_COLORS[self.class]:WrapTextInColorCode(self.name)
        end
    end
end

---Generate random rolls for all dummy players
---@param rollMax integer
---@return roll[]
local function GenerateRolls(rollMax)
    local rolls = {}
    local rollArt = Core.ROLL_TIERS[rollMax] or "mainspec"
    for _, player in ipairs(DUMMY_PLAYERS) do
        table.insert(rolls, {
            player = player,
            roll = math.random(1, rollMax),
            rollArt = rollArt,
        })
    end
    return rolls
end

---Simulate a full loot scenario
function ObisLootAddon:DebugSimulateLoot()
    PrepareDummyPlayers()
    local itemLink = DUMMY_ITEMS[math.random(1, #DUMMY_ITEMS)]

    self.currentItem = itemLink
    self.currentId.items[itemLink] = {
        count = 1,
        gewinner = {},
        rolls = GenerateRolls(100),
    }

    table.sort(self.currentId.items[itemLink].rolls, Core.SortRolls)
    self:UpdateRollDisplay()
    self:Print("Debug: Simulierter Loot für " .. itemLink)
end

---Simulate a draw scenario (two players with same roll)
function ObisLootAddon:DebugSimulateDraw()
    PrepareDummyPlayers()
    local itemLink = DUMMY_ITEMS[1]
    local tiedRoll = math.random(50, 100)

    self.currentItem = itemLink
    self.currentId.items[itemLink] = {
        count = 1,
        gewinner = {},
        rolls = {
            { player = DUMMY_PLAYERS[1], roll = tiedRoll, rollArt = "mainspec" },
            { player = DUMMY_PLAYERS[2], roll = tiedRoll, rollArt = "mainspec" },
            { player = DUMMY_PLAYERS[3], roll = tiedRoll - 10, rollArt = "mainspec" },
        },
    }

    table.sort(self.currentId.items[itemLink].rolls, Core.SortRolls)
    self:UpdateRollDisplay()
    self:Print("Debug: Simuliertes Unentschieden für " .. itemLink)
end
```

- [ ] **Step 2: Add `debug` subcommand to Events.lua**

In the `Commands` function in Events.lua, add a new `elseif` branch:

```lua
    elseif cmd == "debug" then
        local subcmd = item
        if subcmd == "loot" then
            ObisLootAddon:DebugSimulateLoot()
        elseif subcmd == "draw" then
            ObisLootAddon:DebugSimulateDraw()
        else
            ObisLootAddon:Print("Debug Befehle:")
            ObisLootAddon:Print("  /ola debug loot  - Simuliert einen Loot-Drop")
            ObisLootAddon:Print("  /ola debug draw  - Simuliert ein Unentschieden")
        end
```

- [ ] **Step 3: Remove old /obistest from liverolls.lua**

Delete the entire block from `-- Test-Kommando` to the end of the file (lines 98-159).

- [ ] **Step 4: Add DebugMode.lua to TOC**

In `ObisLootAddon.toc`, add after `TradeAssistant.lua`:

```
DebugMode.lua
```

- [ ] **Step 5: Commit**

```bash
git add DebugMode.lua Events.lua liverolls.lua ObisLootAddon.toc
git commit -m "feat: add /ola debug commands for loot and draw simulation"
```

---

## Task 6: Update TOC (final)

Ensure all new files are in the TOC in the correct load order.

**Files:**
- Modify: `ObisLootAddon.toc`

### Steps

- [ ] **Step 1: Verify final TOC load order**

The final TOC should be:

```toc
## Interface: 120000
## Title: ObisLootAddon
## Notes: Für mehr Überblick beim Loot verteilen
## Author: zacki
## Version: 2.1.0
## X-Curse-Project-ID: 999999
## SavedVariables: ObisLootAddonDB

# Libraries
libs/Ace3/LibStub/LibStub.lua
libs/Ace3/CallbackHandler-1.0/CallbackHandler-1.0.lua
libs/Ace3/AceAddon-3.0/AceAddon-3.0.lua
libs/Ace3/AceDB-3.0/AceDB-3.0.lua
libs/Ace3/AceEvent-3.0/AceEvent-3.0.lua
libs/Ace3/AceConsole-3.0/AceConsole-3.0.lua
libs/Ace3/AceGUI-3.0/AceGUI-3.0.lua
libs/LibDBIcon-1.0/embeds.xml

# Addon core (load order matters)
classes.lua
ObisLoot.lua
player.lua
Core.lua
Events.lua
TradeAssistant.lua
DebugMode.lua

# UI (one file per window)
gui.lua
liverolls.lua
MainRosterGUI.lua
```

- [ ] **Step 2: Bump version**

Update the version to 2.1.0 in the TOC.

- [ ] **Step 3: Run tests**

Run: `lua tests.lua`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add ObisLootAddon.toc
git commit -m "chore: update TOC with new files and bump to v2.1.0"
```
