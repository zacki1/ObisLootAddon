
--ENCOUNTER_START
--RAID_INSTANCE_WELCOME
--LOOT_HISTORY_UPDATE_ENCOUNTER
--C_LootHistory.GetSortedDropsForEncounter(encounterID) : drops
LootTrackingActive = false
local ids = {
    --[[
    id = 0,
    items = {
        [itemId] = {   
            count = 1,
            gewinner = {
                {
                    player = "",
                    roll = 0,
                    rollart = 0,
                }
            },
            rolls = {
                player = "",
                roll = 0,
                rollart = 0
            },
        },        
    }
    ]]
}
local currentId = {
    id = 0,
    items = {},
}
local currentItem
local rolls ={
    [100] = "mainspec",
    [50] = "offspec",
    [10] = "transmog",
    ["mainspec"] = 100,
    ["offspec"] = 50,
    ["transmog"] = 10,
}
ObisLootAddon = LibStub("AceAddon-3.0"):NewAddon("ObisLootAddon", "AceEvent-3.0")
local mainFrame = CreateFrame("Frame", "OlaMainFrame", UIParent, "BasicFrameTemplateWithInset")
mainFrame:SetSize(500,350)
mainFrame:SetPoint("CENTER",UIParent,"CENTER",0,0)
mainFrame.TitleBg:SetHeight(30)
mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mainFrame.title:SetPoint("TOPLEFT",mainFrame.TitleBg, "TOPLEFT", 5, -3)
mainFrame.title:SetText("Obis Loot Addon")
mainFrame:Hide()

mainFrame:EnableMouse(true)
mainFrame:SetMovable(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", function (self)
    self:StartMoving()
end)
mainFrame:SetScript("OnDragStop", function (self)
    self:StopMovingOrSizing()
end)

table.insert(UISpecialFrames, "OlaMainFrame")

local function ParseRollText(text)
    if not text or string.match(text, "(%a+) würfelt. Ergebnis: (%d+) %(1%-(%d+)%)") == nil then
        return false
    else
        local name, roll, max =
            string.match(text, "(%a+) würfelt. Ergebnis: (%d+) %(1%-(%d+)%)")
        return true, name, tonumber(roll), tonumber(max)
    end
end
local function SortRolls(left, right)
    if left.rollArt ~= right.rollArt then
        return rolls[left.rollArt] > rolls[right.rollArt]
    end

    return left.roll > right.roll
end
local function GetCountWins(player)
    local count = 0
    for _, item in pairs(currentId.items) do
        for _, gewinner in pairs(item.gewinner) do
            if gewinner.player == player then count = count + 1 end
        end
    end
    return count
end
local function ErmittleGewinner(rolls)
    local gewinner = {}
    for i = 1,#rolls do
        local roll = rolls[i]
        local roll2 = rolls[i+1]
        if not roll2 or roll.rollArt ~= roll2.rollArt then
            table.insert(gewinner, roll)
            break
        elseif roll.rollArt == roll2.rollArt and GetCountWins(roll.player) == GetCountWins(roll2.player) then
            table.insert(gewinner, roll)
        elseif roll.rollArt == roll2.rollArt and GetCountWins(roll.player) < GetCountWins(roll2.player) then
            table.insert(gewinner, roll)
            break
        end
    end
    return gewinner
end

local function ErgebnisseAusgeben()
    table.sort(currentId.items[currentItem].rolls, SortRolls)
    local gewinner = ErmittleGewinner(currentId.items[currentItem].rolls)
    for _, win in pairs(gewinner) do
        local msg = win.rollArt .. ": " .. win.player .. " hat mit " .. win.roll .. " gewonnen!"
        print(msg)
        SendChatMessage(msg, "RAID")
    end
    if #gewinner == currentId.items[currentItem].count then
        currentId.items[currentItem].gewinner = gewinner
    elseif #gewinner > currentId.items[currentItem].count then
        currentId.items[currentItem].gewinner = gewinner
        msg = "Unentschieden! Bitte \"/ola reroll\" ausführen"
        print(msg)
        SendChatMessage(msg, "RAID")
    else
        msg = "Fehler beim ermitteln der Gewinner"
        print(msg)
        SendChatMessage(msg, "RAID")
    end
end

local function HasAlreadyRolled(player)
    local found = false
    for _, roll in pairs(currentId.items[currentItem].rolls) do
        found = roll.player == player
        if found then break end
    end
    return found
end

function ObisLootAddon:CHAT_MSG_SYSTEM(event, msg)
    local isRoll,player,roll,maxroll = ParseRollText(msg)
    if(isRoll) then
        if not HasAlreadyRolled(player) then
            table.insert(currentId.items[currentItem].rolls, {roll = roll, player = player, rollArt = rolls[maxroll]})
        end
    end
end

function ObisLootAddon:ToggleMainFrame()
    if not mainFrame:IsShown() then
        mainFrame:Show()
    else
        mainFrame:Hide()
    end
end

local function SaveId()
    ObisLootAddonDB.Ids[currentId.id] = currentId.items
end

local function Commands(msg, editbox)
    local _, _, cmd, args = string.find(msg, "%s?(%w+)%s?(.*)")
    if cmd == "post" and args ~= "" then
        local _,_,item,count = string.find(args, "(.-)%s?(%d?)$")
        count = tonumber(count)
        print(args)
        print(item)
        print(count)
        if not count then count = 1 end
        currentItem = item
        currentId.items[currentItem] = {count = count,gewinner = {}, rolls = {}}
        SendChatMessage(args, "RAID")
        ObisLootAddon:RegisterEvent("CHAT_MSG_SYSTEM")

    elseif cmd == "stop" then
        ObisLootAddon:UnregisterEvent("CHAT_MSG_SYSTEM")
        ErgebnisseAusgeben()
        SaveId()

    elseif cmd == "reroll" then
        SendChatMessage("Reroll für: " .. currentItem, "RAID")
        local count = currentId.items[currentItem].count
        currentItem = currentItem .. "_r"
        currentId.items[currentItem] = {count = count,gewinner = {}, rolls = {}}

        ObisLootAddon:RegisterEvent("CHAT_MSG_SYSTEM")

    elseif cmd == "reset" then
        table.wipe(ObisLootAddonDB.Ids[0])
        currentId.id = 0
        currentId.items = ObisLootAddonDB.Ids[0] or {}

    elseif cmd == "dump" then
        DevTools_Dump(currentId)
        
    else
        if mainFrame:IsShown() then
            mainFrame:Hide()
        else
            mainFrame:Show()
        end
    end
end


SLASH_OLA1 = "/ola"
SlashCmdList["OLA"] = Commands

function ObisLootAddon:GetInstanceInformation()
	local zone, zonetype, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, mapid = GetInstanceInfo()
    if(zonetype ~= "raid") then return nil end
	return zone, zonetype, difficultyIndex, difficultyName
end

function ObisLootAddon:OnInitialize()
    if not ObisLootAddonDB then
        ObisLootAddonDB = {}
    end
    if not ObisLootAddonDB.Ids then
        ObisLootAddonDB.Ids = {}
    end
    currentId.id = 0
    currentId.items = ObisLootAddonDB.Ids[0] or {}
    ObisLootAddon:LoadMinimap()
end