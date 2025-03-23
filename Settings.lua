local checkboxes = 0
local settings = {
    {
        settingText = "Enable Tracking of Kills",
        settingKey = "enableKillTracking",
        settingTooltip = "While enabled, your kills will be tracked.",
    },
    {
        settingText = "Enable tracking of Currency",
        settingKey = "enableCurrencyTracking",
        settingTooltip = "While enabled, your currency gained will be tracked.",
    },
}


local settingsFrame = CreateFrame("Frame","SettingsFrame", UIParent, "BasicFrameTemplateWithInset")
settingsFrame:SetSize(400,300)
settingsFrame:SetPoint("CENTER")
settingsFrame.TitleBg:SetHeight(30)
settingsFrame.title = settingsFrame:CreateFontString(nil,"OVERLAY", "GameFontHighlight")
settingsFrame.title:SetPoint("CENTER", settingsFrame.TitleBg, "CENTER", 0,0)
settingsFrame.title:SetText("Settings")
settingsFrame:Hide()
settingsFrame:EnableMouse(true)
settingsFrame:SetMovable(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
settingsFrame:SetScript("OnDragStop", function (self)
    self:StopMovingOrSizing()
end)

local function CreateCheckbox(text, key, tooltip)
    local checkbox = CreateFrame("CheckButton", "CheckboxID" .. checkboxes, settingsFrame, "UICheckButtonTemplate")
    checkbox.Text:SetText(text)
    checkbox:SetPoint("TOPLEFT",settingsFrame,"TOPLEFT",10,-30 + (checkboxes * -30))
    if ObisLootAddonDB.settingsKeys[key] == nil then
        ObisLootAddonDB.settingsKeys[key] = true
    end

    checkbox:SetChecked(ObisLootAddonDB.settingsKeys[key])
    checkbox:SetScript("OnEnter", function (self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText(tooltip,nil,nil,nil,nil,true)
    end)
    checkbox:SetScript("OnLeave", function (self)
        GameTooltip:Hide()
    end)
    checkbox:SetScript("OnClick", function (self)
        ObisLootAddonDB.settingsKeys[key] = self:GetChecked()
    end)
    checkboxes = checkboxes + 1
    return checkbox
end

local eventListenerFrame = CreateFrame("Frame", "SettingsEventListenerFrame",UIParent)
eventListenerFrame:RegisterEvent("PLAYER_LOGIN")
eventListenerFrame:SetScript("OnEvent", function (self, event)
    if event == "PLAYER_LOGIN" then
        if not ObisLootAddonDB.settingsKeys then
            ObisLootAddonDB.settingsKeys = {}
        end

        for _, setting in pairs(settings) do
            CreateCheckbox(setting.settingText,setting.settingKey,setting.settingTooltip)
        end
    end
end)

local addon = LibStub("AceAddon-3.0"):NewAddon("ObisLootAddon")
MinimapButton = LibStub("LibDBIcon-1.0", true)
local miniButton = LibStub("LibDataBroker-1.1"):NewDataObject("ObisLootAddon", {
    type = "data source",
    text = "Obis Loot Addon",
    icon = "Interface\\AddOns\\ObisLootAddon\\minimap.tga",
    OnClick = function (self,btn)
        if btn == "LeftButton" then
            ObisLootAddon:ToggleMainFrame()
        elseif btn == "RightButton" then
            if settingsFrame:IsShown() then
                settingsFrame:Hide()
            else
                settingsFrame:Show()
            end
        end
    end,
    OnTooltipShow = function (tooltip)
        if not tooltip or not tooltip.AddLine then
            return
        end
        tooltip:AddLine("ObisLootAddon\n\nLeft-Click: Open\nRight-Click: Open Settings",nil,nil,nil,nil)
    end,
})

function addon:OnInitialize()
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