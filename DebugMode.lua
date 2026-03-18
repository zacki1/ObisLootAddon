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
