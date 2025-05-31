--ENCOUNTER_START
--RAID_INSTANCE_WELCOME
--LOOT_HISTORY_UPDATE_ENCOUNTER
--C_LootHistory.GetSortedDropsForEncounter(encounterID) : drops
local private = select(2,...)
LootTrackingActive = false

---@type id
ObisLootAddon.currentId = {
    id = 0,
    items = {},
    rerollArchive = {},
    roster = {}
}

---@class item
ObisLootAddon.currentItem = nil

---@type {[integer | string]: string | integer}
local rolls ={
    [100] = "mainspec",
    [50] = "offspec",
    [10] = "transmog",
    ["mainspec"] = 100,
    ["offspec"] = 50,
    ["transmog"] = 10,
}

local IsReroll = false
local IsRecording = false

---Returns the values of the roll system message
---@param text string
---@return roll? roll
local function ParseRollText(text)
    if not text then
        return nil
    else
        local name, roll, max =
            strmatch(text, "(.+) würfelt. Ergebnis: (%d+) %(1%-(%d+)%)")
        if not name then return nil end
        local player = ObisLootAddon:GetPlayer(name)
        if not player then return nil end
        return {player = player, roll = tonumber(roll), rollArt = rolls[tonumber(max)]}
    end
end

---Sort for rollArt then roll. Both descending order
---@param left roll
---@param right roll
---@return boolean
function private.SortRolls(left, right)
    if left.rollArt ~= right.rollArt then
        return rolls[left.rollArt] > rolls[right.rollArt]
    end
    if left.player.isMain ~= right.player.isMain then
        return left.player.isMain
    end

    return left.roll > right.roll
end

function private.SortRoster(left, right)
    return string.lower(left.name) < string.lower(right.name)
end

---Get number of Items won by player for given rollArt
---@param player player
---@param rollArt string
---@return integer
local function GetCountWins(player, rollArt)
    local count = 0
    for _, item in pairs(ObisLootAddon.currentId.items) do
        for _, gewinner in pairs(item.gewinner) do
            if gewinner.player.guid == player.guid and gewinner.rollArt == rollArt then count = count + 1 end
        end
    end
    return count
end

---Get winners for given item
---Returns multiple winners if draw or multiple instances of the item are rolled for
---@param rolls table
---@param count integer
---@return table
function ObisLootAddon:ErmittleGewinner(rolls, count)
    local gewinner = {}
    local i = 1
    while(i <= #rolls) do
        local roll = rolls[i]
        local roll2 = rolls[i+1]
        if not roll2 or roll.rollArt ~= roll2.rollArt or roll.player.IsMain ~= roll2.player.IsMain then
            table.insert(gewinner, roll)
        elseif roll.rollArt == roll2.rollArt then
            if GetCountWins(roll.player, roll.rollArt) < GetCountWins(roll2.player,roll2.rollArt) then
                table.insert(gewinner, roll)
            elseif GetCountWins(roll.player, roll.rollArt) == GetCountWins(roll2.player, roll2.rollArt) then
                if roll.roll == roll2.roll then
                    table.insert(gewinner, roll)
                    table.insert(gewinner, roll2)
                    i = i + 1
                elseif roll.roll > roll2.roll then
                    table.insert(gewinner, roll)
                end
            end
        end
        i = i + 1
        if #gewinner >= count then break end
    end
    return gewinner
end

function ObisLootAddon:ErgebnisseAusgeben()
    table.sort(ObisLootAddon.currentId.items[ObisLootAddon.currentItem].rolls, private.SortRolls)
    local gewinner = ObisLootAddon:ErmittleGewinner(ObisLootAddon.currentId.items[ObisLootAddon.currentItem].rolls, ObisLootAddon.currentId.items[ObisLootAddon.currentItem].count)
    for _, win in pairs(gewinner) do
        local msg = win.rollArt .. ": " .. win.player.name .. " hat mit " .. win.roll .. " gewonnen!"
        SendChatMessage(msg, "RAID")
    end
    if #gewinner == ObisLootAddon.currentId.items[ObisLootAddon.currentItem].count then
        ObisLootAddon.currentId.items[ObisLootAddon.currentItem].gewinner = gewinner
    elseif #gewinner > ObisLootAddon.currentId.items[ObisLootAddon.currentItem].count then
        ObisLootAddon.currentId.items[ObisLootAddon.currentItem].gewinner = gewinner
        local msg = "Unentschieden! Bitte \"/ola reroll\" ausführen"
        SendChatMessage(msg, "RAID")
    else
        local msg = "Fehler beim ermitteln der Gewinner"
        if ObisLootAddon.currentItem then
            ObisLootAddon.currentId.items[ObisLootAddon.currentItem] = nil
        end
        SendChatMessage(msg, "RAID")
    end
end
---Check if the given name has already rolled for the item
---@param playerGuid string
---@return boolean
local function HasAlreadyRolled(playerGuid)
    local found = false
    for _, roll in pairs(ObisLootAddon.currentId.items[ObisLootAddon.currentItem].rolls) do
        found = roll.player.guid == playerGuid
        if found then break end
    end
    return found
end

---Check on reroll if the player has already rolled for the item before
---@param playerGuid string
---@return boolean
local function IsRerollEligible(playerGuid)
    local hasRolled = false
    for _,winner in pairs(ObisLootAddon.rerollArchive[ObisLootAddon.currentItem].gewinner) do
        if winner.guid == playerGuid then hasRolled = true end
    end
    return hasRolled
end

function ObisLootAddon:SaveId()
    ObisLootAddonDB.Ids[ObisLootAddon.currentId.id] = ObisLootAddon.currentId
end

function ObisLootAddon:CHAT_MSG_RAID(event, msg, player)
    if IsRecording then
        local itemLink, count = strmatch(msg, "(|Hitem:[^|]+|h|r)%s*(%d*)")
        if itemLink then
            if ObisLootAddon.currentItem then
                ObisLootAddon:ErmittleGewinner(ObisLootAddon.currentId.items[ObisLootAddon.currentItem].rolls, ObisLootAddon.currentId.items[ObisLootAddon.currentItem].count)
                ObisLootAddon:SaveId()
            end
            ObisLootAddon.currentItem = itemLink
            count = tonumber(count) or 1
            if not ObisLootAddon.currentId.items[itemLink] then
                ObisLootAddon.currentId.items[itemLink] = {count = count, gewinner = {}, rolls = {}}
            end
            ObisLootAddon:Print("Neues Item aufgezeichnet: " .. itemLink .. (count > 1 and " x" .. count or ""))
            ObisLootAddon:UpdateRollDisplay()
        end
    end
end

function ObisLootAddon:CHAT_MSG_RAID_LEADER(event, msg, player)
    ObisLootAddon:CHAT_MSG_RAID(event,msg, player)
end

function ObisLootAddon:CHAT_MSG_SYSTEM(event, msg)
    local roll = ParseRollText(msg)
    if roll then
        if not IsRecording then
            if not HasAlreadyRolled(roll.player.guid) then
                if not IsReroll then
                    table.insert(ObisLootAddon.currentId.items[ObisLootAddon.currentItem].rolls, roll)
                    ObisLootAddon:UpdateRollDisplay()
                elseif IsReroll and IsRerollEligible(roll.player.guid) then
                    table.insert(ObisLootAddon.currentId.items[ObisLootAddon.currentItem].rolls, roll)
                    ObisLootAddon:UpdateRollDisplay()
                end
            end
        else
            if ObisLootAddon.currentItem and not HasAlreadyRolled(roll.player.guid) then
                table.insert(ObisLootAddon.currentId.items[ObisLootAddon.currentItem].rolls, roll)
                ObisLootAddon:UpdateRollDisplay()
            end
        end
    end
end



local function Commands(msg, editbox)
    local cmd, item, count = ObisLootAddon:GetArgs(msg, 3)
    if cmd == "post" and item then
        count = tonumber(count)
        if not count then count = 1 end
        ObisLootAddon.currentItem = item
        ObisLootAddon.currentId.items[item] = {count = count,gewinner = {}, rolls = {}}
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
        ObisLootAddon.currentId.items[ObisLootAddon.currentItem] = {count = origCount,gewinner = {}, rolls = {}}
        IsReroll = true
        ObisLootAddon:RegisterEvent("CHAT_MSG_SYSTEM")
    elseif cmd == "reset" then
        table.wipe(ObisLootAddonDB.Ids)
        ObisLootAddon.currentId = {
            id = 0,
            items = {},
            rerollArchive = {},
            roster = {}
        }
        ObisLootAddonDB.Ids[0] = ObisLootAddon.currentId;
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
                ObisLootAddon:ErmittleGewinner(ObisLootAddon.currentId.items[ObisLootAddon.currentItem].rolls, ObisLootAddon.currentId.items[ObisLootAddon.currentItem].count)
                ObisLootAddon:ErgebnisseAusgeben()
                ObisLootAddon:SaveId()
            end
            IsRecording = false
            ObisLootAddon.currentItem = nil
            ObisLootAddon:UnregisterEvent("CHAT_MSG_SYSTEM")
            ObisLootAddon:Print("Aufzeichnung beendet")
        elseif subcmd == "winner" and ObisLootAddon.currentItem then
            ObisLootAddon:ErmittleGewinner(ObisLootAddon.currentId.items[ObisLootAddon.currentItem].rolls, ObisLootAddon.currentId.items[ObisLootAddon.currentItem].count)
            ObisLootAddon:ErgebnisseAusgeben()
            ObisLootAddon:SaveId()
        end
    end
end


ObisLootAddon:RegisterChatCommand("ola", Commands)

function ObisLootAddon:GetInstanceInformation()
	local zone, zonetype, difficultyIndex, difficultyName, _, _, _, _ = GetInstanceInfo()
    if(zonetype ~= "raid") then return nil end
	return zone, zonetype, difficultyIndex, difficultyName
end

function ObisLootAddon:OnInitialize()
    if not ObisLootAddonDB then ObisLootAddonDB = {} end
    if not ObisLootAddonDB.Ids then ObisLootAddonDB.Ids = {} end
    if not ObisLootAddonDB.MainRoster then ObisLootAddonDB.MainRoster = {} end
    ObisLootAddon.currentId = ObisLootAddonDB.Ids[0] or ObisLootAddon.currentId
    ObisLootAddon:LoadMinimap()
    ObisLootAddon:RegisterEvent("GROUP_ROSTER_UPDATE")
    ObisLootAddon:RegisterEvent("CHAT_MSG_RAID")
    ObisLootAddon:RegisterEvent("CHAT_MSG_RAID_LEADER")
end

function ObisLootAddon:GetRaidMembers()
    local memberList = {}
    for i = 1, 40 do
        local name = GetRaidRosterInfo(i)
        if name then
            local player = ObisLootAddon:GetPlayer(name)
            table.insert(memberList, player)
        end
    end
    table.sort(memberList, private.SortRoster)
    return memberList
end


---@param player player
function ObisLootAddon:AddToCurrentId(player)
    if not ObisLootAddon.currentId.roster[player.guid] then
        ObisLootAddon.currentId.roster[player.guid] = player
    end
    table.sort(ObisLootAddon.currentId.roster,private.SortRoster)
end

function ObisLootAddon:GetMemberNamesOfCurrentId()
    local names = {}
    for _,player in pairs(ObisLootAddon.currentId.roster) do
        player = ObisLootAddon:GetPlayer(player.guid)
        table.insert(names, player:GetColoredName())
    end
    return names
end

function ObisLootAddon:GROUP_ROSTER_UPDATE()
    if not IsInRaid() then return end
    local memberList = ObisLootAddon:GetRaidMembers()
    for _, member in pairs(memberList) do
        ObisLootAddon:AddToMainRoster(member)
        ObisLootAddon:AddToCurrentId(member)
    end
end

function ObisLootAddon:PrintListInChat(item)
    local list = ObisLootAddonDB.Ids[0].items[item].rolls
    for i,roll in pairs(list) do
        local msg = i..". " .. roll.player.name .. " mit " .. roll.roll .. " " .. roll.rollArt
        SendChatMessage(msg, "RAID")
    end
end