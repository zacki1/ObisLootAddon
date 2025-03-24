if not ObisLootAddonDB then
    ObisLootAddonDB = {}
end
local rolls ={
    main = {},
    offspec = {},
    transmog = {}
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
    return left.roll > right.roll
end

local function ErgebnisseAusgeben()
    table.sort(rolls.main, SortRolls)
    table.sort(rolls.offspec, SortRolls)
    table.sort(rolls.transmog, SortRolls)
    local mainWinner = {}
    local osWinner = {}
    local tsWinner = {}
    for _, roll in ipairs(rolls.main) do
        if next(mainWinner) == nil or mainWinner[1].roll == roll.roll then
            table.insert(mainWinner , roll)
        end
    end
    for _, roll in ipairs(rolls.offspec) do
        if next(osWinner) == nil or osWinner[1].roll == roll.roll then
            table.insert(osWinner, roll)
        end
    end
    for _, roll in ipairs(rolls.transmog) do
        if next(tsWinner) == nil or tsWinner[1].roll == roll.roll then
            table.insert(tsWinner, roll)
        end
    end
    if next(mainWinner) ~= nil then
        for _, roll in pairs(mainWinner) do
             print("Mainspec: " .. roll.player .. " hat mit " .. roll.roll .. " gewonnen!")
        end
    elseif next(osWinner) ~= nil then
        for _, roll in pairs(osWinner) do
            print("Offspec: " .. roll.player .. " hat mit " .. roll.roll .. " gewonnen!")
        end
    elseif next(tsWinner) ~= nil then
        for _, roll in pairs(tsWinner) do
            print("Transmog: " .. roll.player .. " hat mit " .. roll.roll .. " gewonnen!")
        end
    end
    table.wipe(rolls.main)
    table.wipe(rolls.offspec)
    table.wipe(rolls.transmog)
end

function ObisLootAddon:CHAT_MSG_SYSTEM(event, msg)
        local isRoll,player,roll,maxroll = ParseRollText(msg)
        if(isRoll) then
            if maxroll == 100 then
                table.insert(rolls.main, {player = player,roll = roll})
            elseif maxroll == 50 then
                table.insert(rolls.offspec, {player = player,roll = roll})
            elseif maxroll == 10 then
                table.insert(rolls.transmog, {player = player,roll = roll})
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


local function Commands(msg, editbox)
    local _, _, cmd, args = string.find(msg, "%s?(%w+)%s?(.*)")
    if cmd == "post" and args ~= "" then
        SendChatMessage(args, "RAID")
        ObisLootAddon:RegisterEvent("CHAT_MSG_SYSTEM")
    elseif cmd == "stop" then
        print("stop the count")
        ObisLootAddon:UnregisterEvent("CHAT_MSG_SYSTEM")
        ErgebnisseAusgeben()
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