MinimapButton = LibStub("LibDBIcon-1.0", true)
local miniButton = LibStub("LibDataBroker-1.1"):NewDataObject("ObisLootAddon", {
    type = "data source",
    text = "Obis Loot Addon",
    icon = "Interface\\AddOns\\ObisLootAddon\\minimap.tga",
    OnClick = function (self,btn)
        if btn == "LeftButton" then
            ObisLootAddon:ToggleMainFrame()
        elseif btn == "RightButton" then
            ObisLootAddon:ToggleRosterMainFrame()
        end
    end,
    OnTooltipShow = function (tooltip)
        if not tooltip or not tooltip.AddLine then
            return
        end
        tooltip:AddLine("ObisLootAddon\n\nLeft-Click: Open\nRight-Click: Open Settings",nil,nil,nil,nil)
    end,
})

function ObisLootAddon:LoadMinimap()
    self.db = LibStub("AceDB-3.0"):New("MinimapPOS", {
        profile = {
            minimap = {
                hide = false
            }
        }
    })

    MinimapButton:Register("ObisLootAddon", miniButton, self.db.profile.minimap)
end

MinimapButton:Show("Obis Loot Addon")