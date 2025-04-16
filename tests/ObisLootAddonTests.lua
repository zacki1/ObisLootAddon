local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local Test = LibStub("LibUnitTest-1.0")

local function TestSuite()
    Test.Suite("ObisLootAddon Tests", function()
        Test.Test("ParseRollText", function()
            local testCases = {
                {
                    input = "Spieler würfelt. Ergebnis: 100 (1-100)",
                    expected = {
                        player = "Spieler",
                        roll = 100,
                        rollArt = "mainspec"
                    }
                },
                {
                    input = "Spieler würfelt. Ergebnis: 50 (1-50)",
                    expected = {
                        player = "Spieler",
                        roll = 50,
                        rollArt = "offspec"
                    }
                }
            }

            for _, testCase in ipairs(testCases) do
                local result = addon.ParseRollText(testCase.input)
                Test.Equals(testCase.expected.roll, result.roll, "Roll value should match")
                Test.Equals(testCase.expected.rollArt, result.rollArt, "Roll type should match")
            end
        end)

        Test.Test("SortRolls", function()
            local testCases = {
                {
                    left = {rollArt = "mainspec", roll = 100, player = {isMain = true}},
                    right = {rollArt = "offspec", roll = 100, player = {isMain = true}},
                    expected = true
                },
                {
                    left = {rollArt = "mainspec", roll = 50, player = {isMain = true}},
                    right = {rollArt = "mainspec", roll = 100, player = {isMain = true}},
                    expected = false
                }
            }

            for _, testCase in ipairs(testCases) do
                local result = addon.SortRolls(testCase.left, testCase.right)
                Test.Equals(testCase.expected, result, "Sort order should match")
            end
        end)
    end)
end

-- Registriere die Tests
Test.RegisterTestSuite(TestSuite) 