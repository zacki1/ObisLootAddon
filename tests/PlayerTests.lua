local addonName, addon = ...
local Test = LibStub("LibUnitTest-1.0")

local function TestSuite()
    Test.Suite("Player Tests", function()
        Test.Test("GetPlayer", function()
            local testCases = {
                {
                    name = "TestSpieler",
                    expected = {
                        name = "TestSpieler",
                        guid = "Player-1234-5678",
                        isMain = true
                    }
                }
            }

            for _, testCase in ipairs(testCases) do
                local result = addon:GetPlayer(testCase.name)
                Test.Equals(testCase.expected.name, result.name, "Player name should match")
                Test.Equals(testCase.expected.isMain, result.isMain, "Main status should match")
            end
        end)

        Test.Test("GetColoredName", function()
            local testCases = {
                {
                    player = {
                        name = "TestSpieler",
                        class = "WARRIOR"
                    },
                    expected = "|cFFC79C6ETestSpieler|r"
                }
            }

            for _, testCase in ipairs(testCases) do
                local result = addon:GetColoredName(testCase.player)
                Test.Equals(testCase.expected, result, "Colored name should match")
            end
        end)
    end)
end

-- Registriere die Tests
Test.RegisterTestSuite(TestSuite) 