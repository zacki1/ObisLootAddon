
--ENCOUNTER_START
--RAID_INSTANCE_WELCOME
--LOOT_HISTORY_UPDATE_ENCOUNTER
--C_LootHistory.GetSortedDropsForEncounter(encounterID) : drops
LootTrackingActive = false
---@type id
local currentId
local IsReroll = false
---@type id
local currentIdDefault = {
    id = 0,
    items = {},
    rerollArchive = {},
    roster = {}
}
---@class item
local currentItem
---@type {[integer | string]: string | integer}
local rolls ={
    [100] = "mainspec",
    [50] = "offspec",
    [10] = "transmog",
    ["mainspec"] = 100,
    ["offspec"] = 50,
    ["transmog"] = 10,
}

---Returns the values of the roll system message
---@param text string
---@return roll? roll
local function ParseRollText(text)
    if not text then
        return nil
    else
        local name, roll, max =
            string.match(text, "(%a+) würfelt. Ergebnis: (%d+) %(1%-(%d+)%)")
        local player = ObisLootAddon:GetPlayer(name)
        if not player then return nil end
        return {player = player, roll = tonumber(roll), rollArt = rolls[tonumber(max)]}
    end
end

---Sort for rollArt then roll. Both descending order
---@param left roll
---@param right roll
---@return boolean
local function SortRolls(left, right)
    if left.rollArt ~= right.rollArt then
        return rolls[left.rollArt] > rolls[right.rollArt]
    end
    if left.player.isMain ~= right.player.isMain then
        return left.player.isMain
    end

    return left.roll > right.roll
end

---Get number of Items won by player for given rollArt
---@param player string
---@param rollArt string
---@return integer
local function GetCountWins(player, rollArt)
    local count = 0
    for _, item in pairs(currentId.items) do
        for _, gewinner in pairs(item.gewinner) do
            if gewinner.player == player and gewinner.rollArt == rollArt then count = count + 1 end
        end
    end
    return count
end

---Get winners for given item
---Returns multiple winners if draw or multiple instances of the item are rolled for
---@param rolls table
---@param count integer
---@return table
local function ErmittleGewinner(rolls, count)
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

local function ErgebnisseAusgeben()
    table.sort(currentId.items[currentItem].rolls, SortRolls)
    local gewinner = ErmittleGewinner(currentId.items[currentItem].rolls, currentId.items[currentItem].count)
    for _, win in pairs(gewinner) do
        local msg = win.rollArt .. ": " .. win.player:GetColoredName() .. " hat mit " .. win.roll .. " gewonnen!"
        print(msg)
        SendChatMessage(msg, "RAID")
    end
    if #gewinner == currentId.items[currentItem].count then
        currentId.items[currentItem].gewinner = gewinner
    elseif #gewinner > currentId.items[currentItem].count then
        currentId.items[currentItem].gewinner = gewinner
        local msg = "Unentschieden! Bitte \"/ola reroll\" ausführen"
        print(msg)
        SendChatMessage(msg, "RAID")
    else
        local msg = "Fehler beim ermitteln der Gewinner"
        currentId.items[currentItem] = nil
        print(msg)
        SendChatMessage(msg, "RAID")
    end
end

---Check if the given name has already rolled for the item
---@param playerGuid string
---@return boolean
local function HasAlreadyRolled(playerGuid)
    local found = false
    for _, roll in pairs(currentId.items[currentItem].rolls) do
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
    for _,winner in pairs(currentId.rerollArchive[currentItem].gewinner) do
        if winner.guid == playerGuid then hasRolled = true end
    end
    return hasRolled
end

function ObisLootAddon:CHAT_MSG_SYSTEM(event, msg)
    local roll = ParseRollText(msg)
    if roll then
        if not HasAlreadyRolled(roll.player.guid) then
            if not IsReroll then
                table.insert(currentId.items[currentItem].rolls, roll)
            elseif IsReroll and IsRerollEligible(roll.player.guid) then
                table.insert(currentId.items[currentItem].rolls, roll)
            end
        end
    end
end

local function SaveId()
    ObisLootAddonDB.Ids[currentId.id] = currentId
end

local function Commands(msg, editbox)
    local cmd, item, count = ObisLootAddon:GetArgs(msg, 3)
    if cmd == "post" and item then
        count = tonumber(count)
        if not count then count = 1 end
        currentItem = item
        currentId.items[currentItem] = {count = count,gewinner = {}, rolls = {}}
        IsReroll = false
        SendChatMessage(item, "RAID")
        ObisLootAddon:RegisterEvent("CHAT_MSG_SYSTEM")
    elseif cmd == "stop" then
        ObisLootAddon:UnregisterEvent("CHAT_MSG_SYSTEM")
        ErgebnisseAusgeben()
        SaveId()

    elseif cmd == "reroll" then
        SendChatMessage("Reroll für: " .. currentItem, "RAID")
        local origCount = currentId.items[currentItem].count
        currentId.rerollArchive[currentItem] = currentId.items[currentItem]
        currentId.items[currentItem] = {count = origCount,gewinner = {}, rolls = {}}
        IsReroll = true
        ObisLootAddon:RegisterEvent("CHAT_MSG_SYSTEM")

    elseif cmd == "reset" then
        table.wipe(ObisLootAddonDB.Ids)
        currentId = currentIdDefault
    elseif cmd == "dump" then
        DevTools_Dump(currentId)
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
    currentId = ObisLootAddonDB.Ids[0] or currentIdDefault
    ObisLootAddon:LoadMinimap()
    ObisLootAddon:RegisterEvent("GROUP_FORMED")
    ---@class player
local player = ObisLootAddon:GetPlayer("Zackthyr")
ObisLootAddon:AddToMainRoster(player)
end

function ObisLootAddon:GetRaidMembers()
    local memberList = {}
    for i = 1, 40 do
        local name = GetRaidRosterInfo(i)
        if name then
            table.insert(memberList, name)
        else
            break;
        end
    end
    table.sort(memberList, function(left, right)
        return string.lower(left) < string.lower(right)
    end)
    return memberList
end


function ObisLootAddon:GROUP_FORMED()
    ObisLootAddon:RegisterEvent("GROUP_JOINED")
    ObisLootAddon:GROUP_JOINED()
end

function ObisLootAddon:GROUP_JOINED()
    local memberList = ObisLootAddon:GetRaidMembers()
    for _, member in pairs(memberList) do
        local player = ObisLootAddon:GetPlayer(member)
        ObisLootAddon:AddToMainRoster(player)
    end
end