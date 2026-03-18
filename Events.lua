--- Events.lua - Event handlers, chat message processing, and slash commands
--- Bridges Core.lua (pure logic) with WoW API calls.

local Core = ObisLootAddon.Core
local IsReroll = false
local IsRecording = false

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

---Parse a roll system message and resolve the player
---@param text string
---@return roll?
local function ParseRollMessage(text)
    local parsed = Core.ParseRollText(text, ObisLootAddon.ROLL_PATTERN)
    if not parsed then return nil end
    local player = ObisLootAddon:GetPlayer(parsed.name)
    if not player then return nil end
    return {
        player  = player,
        roll    = parsed.rollValue,
        rollArt = parsed.rollArt,
    }
end

---Announce winners in raid chat and store results
function ObisLootAddon:ErgebnisseAusgeben()
    local itemData = self.currentId.items[self.currentItem]
    table.sort(itemData.rolls, Core.SortRolls)
    local gewinner = Core.ErmittleGewinner(itemData.rolls, itemData.count, self.currentId.items)

    for _, win in pairs(gewinner) do
        local msg = win.rollArt .. ": " .. win.player.name .. " hat mit " .. win.roll .. " gewonnen!"
        SendChatMessage(msg, "RAID")
    end

    if #gewinner == itemData.count then
        itemData.gewinner = gewinner
    elseif #gewinner > itemData.count then
        itemData.gewinner = gewinner
        SendChatMessage("Unentschieden! Bitte \"/ola reroll\" ausführen", "RAID")
    else
        SendChatMessage("Fehler beim ermitteln der Gewinner", "RAID")
        if self.currentItem then
            self.currentId.items[self.currentItem] = nil
        end
    end
end

---Handle item links posted in raid chat (recording mode)
function ObisLootAddon:CHAT_MSG_RAID(event, msg, player)
    if not IsRecording then return end

    local itemLink, count = string.match(msg, "(|Hitem:[^|]+|h|r)%s*(%d*)")
    if not itemLink then return end

    if self.currentItem then
        Core.ErmittleGewinner(
            self.currentId.items[self.currentItem].rolls,
            self.currentId.items[self.currentItem].count,
            self.currentId.items
        )
        self:SaveId()
    end

    self.currentItem = itemLink
    count = tonumber(count) or 1
    if not self.currentId.items[itemLink] then
        self.currentId.items[itemLink] = { count = count, gewinner = {}, rolls = {} }
    end
    self:Print("Neues Item aufgezeichnet: " .. itemLink .. (count > 1 and " x" .. count or ""))
    self:UpdateRollDisplay()
end

function ObisLootAddon:CHAT_MSG_RAID_LEADER(event, msg, player)
    self:CHAT_MSG_RAID(event, msg, player)
end

---Detect epic+ items from boss loot the moment they drop
function ObisLootAddon:START_LOOT_ROLL(_, rollID)
    if not IsInRaid() then return end

    local _, _, _, quality, _, _, _, _, _, _, _, _, _, _, itemLink = GetLootRollItemInfo(rollID)
    if not itemLink then return end
    if not Core.IsLootRelevant(quality, 4) then return end

    if not self.currentId.items[itemLink] then
        self.currentId.items[itemLink] = { count = 1, gewinner = {}, rolls = {} }
        self:Print("Boss-Loot erkannt: " .. itemLink)
    else
        self.currentId.items[itemLink].count = self.currentId.items[itemLink].count + 1
        self:Print("Boss-Loot erkannt: " .. itemLink .. " x" .. self.currentId.items[itemLink].count)
    end
end

---Process incoming roll system messages
function ObisLootAddon:CHAT_MSG_SYSTEM(event, msg)
    local roll = ParseRollMessage(msg)
    if not roll then return end

    local itemData = self.currentId.items[self.currentItem]
    if not itemData then return end

    if Core.HasAlreadyRolled(roll.player.guid, itemData.rolls) then return end

    if IsRecording then
        if self.currentItem then
            table.insert(itemData.rolls, roll)
            self:UpdateRollDisplay()
        end
    else
        if not IsReroll then
            table.insert(itemData.rolls, roll)
            self:UpdateRollDisplay()
        elseif Core.IsRerollEligible(roll.player.guid, self.rerollArchive[self.currentItem].gewinner) then
            table.insert(itemData.rolls, roll)
            self:UpdateRollDisplay()
        end
    end
end

---Generate a unique raid ID from instance info and date.
---Returns nil for non-raid instances and LFR (difficulties 7, 17).
---@return string? raidId, string? zone, string? difficultyName, string? dateStr
local function GetOrCreateRaidId()
    local zone, _, difficultyIndex, difficultyName = ObisLootAddon:GetInstanceInformation()
    if not zone then return nil end
    if difficultyIndex == 7 or difficultyIndex == 17 then return nil end
    local dateStr = date("%Y-%m-%d")
    local raidId = zone .. "-" .. difficultyIndex .. "-" .. dateStr
    return raidId, zone, difficultyName, dateStr
end

---Update roster when group composition changes
function ObisLootAddon:GROUP_ROSTER_UPDATE()
    if not IsInRaid() then return end

    -- Create or resume raid ID (nil when not in a raid instance or in LFR)
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

    if not raidId then return end

    local memberList = self:GetRaidMembers()
    for _, member in pairs(memberList) do
        self:AddToMainRoster(member)
        self:AddToCurrentId(member)
    end
end

---Get sorted list of current raid members
---@return player[]
function ObisLootAddon:GetRaidMembers()
    local memberList = {}
    for i = 1, 40 do
        local name = GetRaidRosterInfo(i)
        if name then
            table.insert(memberList, self:GetPlayer(name))
        end
    end
    table.sort(memberList, Core.SortRoster)
    return memberList
end

---Add player to the current raid ID roster
---@param player player
function ObisLootAddon:AddToCurrentId(player)
    if not self.currentId.roster[player.guid] then
        self.currentId.roster[player.guid] = player
    end
    table.sort(self.currentId.roster, Core.SortRoster)
end

---Get colored names of all players in current ID
---@return string[]
function ObisLootAddon:GetMemberNamesOfCurrentId()
    local names = {}
    for _, player in pairs(self.currentId.roster) do
        player = self:GetPlayer(player.guid)
        table.insert(names, player:GetColoredName())
    end
    return names
end

---Print roll list to raid chat
---@param item string
function ObisLootAddon:PrintListInChat(item)
    local list = ObisLootAddonDB.Ids[0].items[item].rolls
    for i, roll in pairs(list) do
        SendChatMessage(i .. ". " .. roll.player.name .. " mit " .. roll.roll .. " " .. roll.rollArt, "RAID")
    end
end

-- Slash commands (/ola)
local function Commands(msg)
    local cmd, item, count = ObisLootAddon:GetArgs(msg, 3)

    local isManager = IsPlayerManager()
    local viewerAllowed = { roll = true, dump = true }
    if not isManager and not viewerAllowed[cmd] then
        ObisLootAddon:Print("Nur Raidleiter und Assists können diesen Befehl nutzen.")
        return
    end

    if cmd == "post" and item then
        count = tonumber(count) or 1
        ObisLootAddon.currentItem = item
        ObisLootAddon.currentId.items[item] = { count = count, gewinner = {}, rolls = {} }
        IsReroll = false
        SendChatMessage("Gewürfelt wird für: " .. item, "RAID")
        ObisLootAddon:UpdateRollDisplay()
        ObisLootAddon:RegisterEvent("CHAT_MSG_SYSTEM")

    elseif cmd == "stop" then
        ObisLootAddon:UnregisterEvent("CHAT_MSG_SYSTEM")
        ObisLootAddon:ErgebnisseAusgeben()
        ObisLootAddon:SaveId()

    elseif cmd == "reroll" then
        SendChatMessage("Reroll für: " .. ObisLootAddon.currentItem, "RAID")
        local origCount = ObisLootAddon.currentId.items[ObisLootAddon.currentItem].count
        ObisLootAddon.rerollArchive[ObisLootAddon.currentItem] = ObisLootAddon.currentId.items[ObisLootAddon.currentItem]
        ObisLootAddon.currentId.items[ObisLootAddon.currentItem] = { count = origCount, gewinner = {}, rolls = {} }
        IsReroll = true
        ObisLootAddon:RegisterEvent("CHAT_MSG_SYSTEM")

    elseif cmd == "reset" then
        table.wipe(ObisLootAddonDB.Ids)
        ObisLootAddon.currentId = {
            id = 0,
            items = {},
            rerollArchive = {},
            roster = {},
        }
        ObisLootAddonDB.Ids[0] = ObisLootAddon.currentId

    elseif cmd == "dump" then
        DevTools_Dump(ObisLootAddon.currentId)

    elseif cmd == "roll" then
        if ObisLootAddon.currentItem then
            ObisLootAddon:UpdateRollDisplay()
        else
            ObisLootAddon:Print("Kein aktives Item zum Anzeigen")
        end

    elseif cmd == "record" then
        local subcmd = item
        if subcmd == "start" then
            IsRecording = true
            ObisLootAddon.currentItem = nil
            ObisLootAddon:RegisterEvent("CHAT_MSG_SYSTEM")
            ObisLootAddon:Print("Aufzeichnung gestartet")
        elseif subcmd == "stop" then
            if ObisLootAddon.currentItem then
                ObisLootAddon:ErgebnisseAusgeben()
                ObisLootAddon:SaveId()
            end
            IsRecording = false
            ObisLootAddon.currentItem = nil
            ObisLootAddon:UnregisterEvent("CHAT_MSG_SYSTEM")
            ObisLootAddon:Print("Aufzeichnung beendet")
        elseif subcmd == "winner" and ObisLootAddon.currentItem then
            ObisLootAddon:ErgebnisseAusgeben()
            ObisLootAddon:SaveId()
        end

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
    end
end

ObisLootAddon:RegisterChatCommand("ola", Commands)
