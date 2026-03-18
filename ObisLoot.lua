--- ObisLoot.lua - Addon entry point, state initialization, AceDB, and minimap button.
--- This file must load before all other addon files.

_G.ObisLootAddon = LibStub("AceAddon-3.0"):NewAddon("ObisLootAddon", "AceEvent-3.0", "AceConsole-3.0")

ObisLootAddon.Interface = {}
---@class player
ObisLootAddon.Player = {}

-- Addon state
---@type id
ObisLootAddon.currentId = {
    id = 0,
    items = {},
    rerollArchive = {},
    roster = {},
}

---@class item
ObisLootAddon.currentItem = nil

-- Archive for reroll data
ObisLootAddon.rerollArchive = {}

-- German locale roll pattern
ObisLootAddon.ROLL_PATTERN = "(.+) würfelt. Ergebnis: (%d+) %(1%-(%d+)%)"

function ObisLootAddon:SaveId()
    ObisLootAddonDB.Ids[self.currentId.id] = self.currentId
end

function ObisLootAddon:GetInstanceInformation()
    local zone, zonetype, difficultyIndex, difficultyName = GetInstanceInfo()
    if zonetype ~= "raid" then return nil end
    return zone, zonetype, difficultyIndex, difficultyName
end

function ObisLootAddon:OnInitialize()
    if not ObisLootAddonDB then ObisLootAddonDB = {} end
    if not ObisLootAddonDB.Ids then ObisLootAddonDB.Ids = {} end
    if not ObisLootAddonDB.MainRoster then ObisLootAddonDB.MainRoster = {} end
    self.currentId = ObisLootAddonDB.Ids[0] or self.currentId
    self:LoadMinimap()
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("CHAT_MSG_RAID")
    self:RegisterEvent("CHAT_MSG_RAID_LEADER")
end

-- Minimap button (previously Settings.lua)
local MinimapButton = LibStub("LibDBIcon-1.0", true)
local miniButton = LibStub("LibDataBroker-1.1"):NewDataObject("ObisLootAddon", {
    type = "data source",
    text = "Obis Loot Addon",
    icon = "Interface\\AddOns\\ObisLootAddon\\minimap.tga",
    OnClick = function(self, btn)
        if btn == "LeftButton" then
            ObisLootAddon:ToggleMainFrame()
        elseif btn == "RightButton" then
            ObisLootAddon:ToggleRosterMainFrame()
        end
    end,
    OnTooltipShow = function(tooltip)
        if not tooltip or not tooltip.AddLine then return end
        tooltip:AddLine("ObisLootAddon\n\nLeft-Click: Open\nRight-Click: Open Settings")
    end,
})

function ObisLootAddon:LoadMinimap()
    self.db = LibStub("AceDB-3.0"):New("MinimapPOS", {
        profile = {
            minimap = { hide = false },
        },
    })
    MinimapButton:Register("ObisLootAddon", miniButton, self.db.profile.minimap)
    MinimapButton:Show("ObisLootAddon")
end
