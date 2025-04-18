local private = select(2, ...)
local AceGUI = LibStub("AceGUI-3.0")

-- Roll Fenster
local RollFrame
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
        AceGUI:Release(widget)
        RollFrame = nil
    end)

    RollFrame:ClearAllPoints()
    RollFrame:SetPoint("RIGHT", UIParent, "RIGHT", -250, 0)

---@diagnostic disable-next-line: invisible
    local frame = RollFrame.frame
    frame:SetResizeBounds(300, 200, 300, 800)

    ScrollContainer = AceGUI:Create("ScrollFrame")--[[@as AceGUIScrollFrame]]
    ScrollContainer:SetLayout("Flow")
    RollFrame:AddChild(ScrollContainer)
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
    table.sort(rolls, private.SortRolls)

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

-- Test-Kommando
SLASH_OBISLOOTTEST1 = "/obistest"
SlashCmdList["OBISLOOTTEST"] = function()
    -- Erstelle Test-Daten
    local testItem = {
        itemLink = "|cffa335ee|Hitem:19019::::::::60:::::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r",
        rolls = {
            {
                player = {
                    name = "Testspieler1",
                    class = "WARRIOR",
                    guid = "Player-1234-5678",
                    realm = "Testrealm",
                    isMain = true,
                    GetColoredName = function(self)
                        return RAID_CLASS_COLORS[self.class]:WrapTextInColorCode(self.name)
                    end
                },
                roll = 100,
                rollArt = "mainspec"
            },
            {
                player = {
                    name = "Testspieler2",
                    class = "PRIEST",
                    guid = "Player-2345-6789",
                    realm = "Testrealm",
                    isMain = false,
                    GetColoredName = function(self)
                        return RAID_CLASS_COLORS[self.class]:WrapTextInColorCode(self.name)
                    end
                },
                roll = 45,
                rollArt = "offspec"
            },
            {
                player = {
                    name = "Testspieler3",
                    class = "MAGE",
                    guid = "Player-3456-7890",
                    realm = "Testrealm",
                    isMain = true,
                    GetColoredName = function(self)
                        return RAID_CLASS_COLORS[self.class]:WrapTextInColorCode(self.name)
                    end
                },
                roll = 50,
                rollArt = "mainspec"
            }
        }
    }

    -- Setze Test-Daten
    ObisLootAddon.currentItem = testItem.itemLink
    ObisLootAddon.currentId = {
        items = {
            [testItem.itemLink] = {
                itemLink = testItem.itemLink,
                rolls = testItem.rolls
            }
        }
    }

    -- Aktualisiere die Anzeige
    ObisLootAddon:UpdateRollDisplay()
end