local AceGUI = LibStub("AceGUI-3.0")
local Core = ObisLootAddon.Core


-- Roll Fenster
local RollFrame = ObisLootAddon.Interface.RollFrame
local ScrollContainer

local function CreateRollFrame()
    if RollFrame then return end

    RollFrame = AceGUI:Create("Frame")--[[@as AceGUIFrame]]
    RollFrame:SetTitle("Rolls")
    RollFrame:SetWidth(300)
    RollFrame:SetHeight(400)
    RollFrame:SetLayout("Fill")
    RollFrame:EnableResize(true)
    RollFrame:SetCallback("OnClose", function(widget)
        widget:Release()
        RollFrame = nil
    end)

    RollFrame:ClearAllPoints()
    RollFrame:SetPoint("RIGHT", UIParent, "RIGHT", -250, 0)

    RollFrame:SetStatusText("")
---@diagnostic disable-next-line: invisible
    RollFrame.statustext:GetParent():Hide()

---@diagnostic disable-next-line: invisible
    local frame = RollFrame.frame
    frame:SetResizeBounds(300, 200, 300, 800)

    ScrollContainer = AceGUI:Create("ScrollFrame")--[[@as AceGUIScrollFrame]]
    ScrollContainer:SetLayout("Flow")
    RollFrame:AddChild(ScrollContainer)

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
end

function ObisLootAddon:UpdateRollDisplay()
    if not self.currentItem then return end

    if not RollFrame then
        CreateRollFrame()
    end

    -- Lösche alte Einträge
    ScrollContainer:ReleaseChildren()

    -- Zeige das aktuelle Item an
    local itemLabel = AceGUI:Create("Label")--[[@as AceGUILabel]]
    itemLabel:SetText(string.format("Aktuelles Item: %s", self.currentItem))
    itemLabel:SetFullWidth(true)
    itemLabel:SetFontObject(GameFontNormal)
    ScrollContainer:AddChild(itemLabel)

    -- Füge eine Trennlinie hinzu
    local separator = AceGUI:Create("Heading")--[[@as AceGUIHeading]]
    separator:SetFullWidth(true)
    ScrollContainer:AddChild(separator)

    local itemData = self.currentId.items[self.currentItem]
    if not itemData then return end

    local rolls = itemData.rolls
    table.sort(rolls, Core.SortRolls)

    if #rolls == 0 then
        local label = AceGUI:Create("Label")--[[@as AceGUILabel]]
        label:SetText("Warte auf Rolls...")
        label:SetFullWidth(true)
        ScrollContainer:AddChild(label)
    else
        for i, roll in ipairs(rolls) do
            local label = AceGUI:Create("Label")--[[@as AceGUILabel]]
            label:SetText(string.format("%d. %s: %d (%s)",
                i,
                roll.player:GetColoredName(),
                roll.roll,
                roll.rollArt))
            label:SetFullWidth(true)
            ScrollContainer:AddChild(label)
        end
    end

    RollFrame:Show()
end
