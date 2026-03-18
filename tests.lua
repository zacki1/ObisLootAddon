--- tests.lua - Standalone unit tests for Core.lua
--- Run with: lua tests.lua
--- Or with busted: busted tests.lua
--- No WoW client required.

local Core = dofile("Core.lua")

-- Minimal test framework
local passed, failed, total = 0, 0, 0

local function test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS: " .. name)
    else
        failed = failed + 1
        print("  FAIL: " .. name .. " - " .. tostring(err))
    end
end

local function assertEqual(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            msg or "assertEqual", tostring(expected), tostring(actual)), 2)
    end
end

local function assertNil(actual, msg)
    if actual ~= nil then
        error(string.format("%s: expected nil, got %s",
            msg or "assertNil", tostring(actual)), 2)
    end
end

local function assertTrue(actual, msg)
    if not actual then
        error(string.format("%s: expected true", msg or "assertTrue"), 2)
    end
end

local function assertFalse(actual, msg)
    if actual then
        error(string.format("%s: expected false", msg or "assertFalse"), 2)
    end
end

-- Test helpers
local function makePlayer(name, guid, isMain, class)
    return {
        name   = name,
        guid   = guid or ("Player-0000-" .. name),
        isMain = isMain ~= false,
        class  = class or "WARRIOR",
    }
end

local function makeRoll(player, rollValue, rollArt)
    return {
        player  = player,
        roll    = rollValue,
        rollArt = rollArt,
    }
end

-- German locale pattern
local DE_PATTERN = "(.+) würfelt. Ergebnis: (%d+) %(1%-(%d+)%)"


-- ===================== ParseRollText =====================
print("\n=== ParseRollText ===")

test("parses mainspec roll (1-100)", function()
    local r = Core.ParseRollText("Zacki würfelt. Ergebnis: 87 (1-100)", DE_PATTERN)
    assertEqual(r.name, "Zacki", "name")
    assertEqual(r.rollValue, 87, "rollValue")
    assertEqual(r.rollArt, "mainspec", "rollArt")
end)

test("parses offspec roll (1-50)", function()
    local r = Core.ParseRollText("Healbot würfelt. Ergebnis: 42 (1-50)", DE_PATTERN)
    assertEqual(r.name, "Healbot", "name")
    assertEqual(r.rollValue, 42, "rollValue")
    assertEqual(r.rollArt, "offspec", "rollArt")
end)

test("parses transmog roll (1-10)", function()
    local r = Core.ParseRollText("Tankboi würfelt. Ergebnis: 7 (1-10)", DE_PATTERN)
    assertEqual(r.name, "Tankboi", "name")
    assertEqual(r.rollValue, 7, "rollValue")
    assertEqual(r.rollArt, "transmog", "rollArt")
end)

test("returns nil for unknown roll range", function()
    assertNil(Core.ParseRollText("Zacki würfelt. Ergebnis: 5 (1-25)", DE_PATTERN))
end)

test("returns nil for non-roll text", function()
    assertNil(Core.ParseRollText("Hello World", DE_PATTERN))
end)

test("returns nil for nil input", function()
    assertNil(Core.ParseRollText(nil, DE_PATTERN))
end)

test("handles roll value of 1", function()
    local r = Core.ParseRollText("Unlucky würfelt. Ergebnis: 1 (1-100)", DE_PATTERN)
    assertEqual(r.rollValue, 1, "rollValue")
end)

test("handles max roll value", function()
    local r = Core.ParseRollText("Lucky würfelt. Ergebnis: 100 (1-100)", DE_PATTERN)
    assertEqual(r.rollValue, 100, "rollValue")
end)


-- ===================== SortRolls =====================
print("\n=== SortRolls ===")

test("mainspec beats offspec regardless of roll value", function()
    local r1 = makeRoll(makePlayer("A"), 1, "mainspec")
    local r2 = makeRoll(makePlayer("B"), 50, "offspec")
    assertTrue(Core.SortRolls(r1, r2))
    assertFalse(Core.SortRolls(r2, r1))
end)

test("offspec beats transmog", function()
    local r1 = makeRoll(makePlayer("A"), 5, "offspec")
    local r2 = makeRoll(makePlayer("B"), 10, "transmog")
    assertTrue(Core.SortRolls(r1, r2))
end)

test("same tier: main beats alt even with lower roll", function()
    local r1 = makeRoll(makePlayer("A", nil, true), 30, "mainspec")
    local r2 = makeRoll(makePlayer("B", nil, false), 95, "mainspec")
    assertTrue(Core.SortRolls(r1, r2))
end)

test("same tier, same main status: higher roll wins", function()
    local r1 = makeRoll(makePlayer("A", nil, true), 90, "mainspec")
    local r2 = makeRoll(makePlayer("B", nil, true), 50, "mainspec")
    assertTrue(Core.SortRolls(r1, r2))
    assertFalse(Core.SortRolls(r2, r1))
end)

test("equal rolls: returns false (stable sort)", function()
    local r1 = makeRoll(makePlayer("A", nil, true), 75, "mainspec")
    local r2 = makeRoll(makePlayer("B", nil, true), 75, "mainspec")
    assertFalse(Core.SortRolls(r1, r2))
    assertFalse(Core.SortRolls(r2, r1))
end)


-- ===================== SortRoster =====================
print("\n=== SortRoster ===")

test("alphabetical sort", function()
    assertTrue(Core.SortRoster({name = "Alpha"}, {name = "Beta"}))
    assertFalse(Core.SortRoster({name = "Beta"}, {name = "Alpha"}))
end)

test("case insensitive", function()
    assertTrue(Core.SortRoster({name = "alpha"}, {name = "Beta"}))
end)

test("same name returns false", function()
    assertFalse(Core.SortRoster({name = "Alpha"}, {name = "Alpha"}))
end)


-- ===================== GetCountWins =====================
print("\n=== GetCountWins ===")

test("counts wins across multiple items", function()
    local items = {
        ["item1"] = {
            gewinner = {
                makeRoll(makePlayer("A", "guid-A"), 90, "mainspec"),
                makeRoll(makePlayer("B", "guid-B"), 80, "mainspec"),
            },
        },
        ["item2"] = {
            gewinner = {
                makeRoll(makePlayer("A", "guid-A"), 45, "offspec"),
            },
        },
    }
    assertEqual(Core.GetCountWins("guid-A", "mainspec", items), 1, "A mainspec")
    assertEqual(Core.GetCountWins("guid-A", "offspec", items), 1, "A offspec")
    assertEqual(Core.GetCountWins("guid-B", "mainspec", items), 1, "B mainspec")
    assertEqual(Core.GetCountWins("guid-B", "offspec", items), 0, "B no offspec")
end)

test("returns 0 for no wins", function()
    assertEqual(Core.GetCountWins("guid-X", "mainspec", {}), 0)
end)

test("returns 0 for empty gewinner lists", function()
    local items = { ["item1"] = { gewinner = {} } }
    assertEqual(Core.GetCountWins("guid-A", "mainspec", items), 0)
end)


-- ===================== ErmittleGewinner =====================
print("\n=== ErmittleGewinner ===")

test("single clear winner", function()
    local items = { ["item1"] = { gewinner = {} } }
    local rolls = {
        makeRoll(makePlayer("A", "guid-A", true), 95, "mainspec"),
        makeRoll(makePlayer("B", "guid-B", true), 60, "mainspec"),
    }
    table.sort(rolls, Core.SortRolls)
    local winners = Core.ErmittleGewinner(rolls, 1, items)
    assertEqual(#winners, 1, "winner count")
    assertEqual(winners[1].player.name, "A", "winner name")
end)

test("draw returns both players", function()
    local items = { ["item1"] = { gewinner = {} } }
    local rolls = {
        makeRoll(makePlayer("A", "guid-A", true), 75, "mainspec"),
        makeRoll(makePlayer("B", "guid-B", true), 75, "mainspec"),
    }
    table.sort(rolls, Core.SortRolls)
    local winners = Core.ErmittleGewinner(rolls, 1, items)
    assertEqual(#winners, 2, "draw should return both")
end)

test("player with fewer prior wins gets priority", function()
    local items = {
        ["item1"] = {
            gewinner = {
                makeRoll(makePlayer("A", "guid-A"), 90, "mainspec"),
            },
        },
    }
    local rolls = {
        makeRoll(makePlayer("A", "guid-A", true), 95, "mainspec"),
        makeRoll(makePlayer("B", "guid-B", true), 90, "mainspec"),
    }
    table.sort(rolls, Core.SortRolls)
    local winners = Core.ErmittleGewinner(rolls, 1, items)
    assertEqual(#winners, 1, "winner count")
    assertEqual(winners[1].player.name, "B", "B wins (fewer prior wins)")
end)

test("multiple winners for multi-drop", function()
    local items = { ["item1"] = { gewinner = {} } }
    local rolls = {
        makeRoll(makePlayer("A", "guid-A", true), 95, "mainspec"),
        makeRoll(makePlayer("B", "guid-B", true), 80, "mainspec"),
        makeRoll(makePlayer("C", "guid-C", true), 60, "mainspec"),
    }
    table.sort(rolls, Core.SortRolls)
    local winners = Core.ErmittleGewinner(rolls, 2, items)
    assertEqual(#winners, 2, "should have 2 winners")
    assertEqual(winners[1].player.name, "A")
    assertEqual(winners[2].player.name, "B")
end)

test("mainspec winner before offspec", function()
    local items = { ["item1"] = { gewinner = {} } }
    local rolls = {
        makeRoll(makePlayer("A", "guid-A", true), 30, "mainspec"),
        makeRoll(makePlayer("B", "guid-B", true), 45, "offspec"),
    }
    table.sort(rolls, Core.SortRolls)
    local winners = Core.ErmittleGewinner(rolls, 1, items)
    assertEqual(winners[1].player.name, "A", "mainspec should win over offspec")
end)

test("empty rolls returns empty", function()
    local winners = Core.ErmittleGewinner({}, 1, {})
    assertEqual(#winners, 0)
end)


-- ===================== HasAlreadyRolled =====================
print("\n=== HasAlreadyRolled ===")

test("detects existing roll", function()
    local rolls = { makeRoll(makePlayer("A", "guid-A"), 90, "mainspec") }
    assertTrue(Core.HasAlreadyRolled("guid-A", rolls))
end)

test("returns false for new player", function()
    local rolls = { makeRoll(makePlayer("A", "guid-A"), 90, "mainspec") }
    assertFalse(Core.HasAlreadyRolled("guid-B", rolls))
end)

test("returns false for empty rolls", function()
    assertFalse(Core.HasAlreadyRolled("guid-A", {}))
end)


-- ===================== IsRerollEligible =====================
print("\n=== IsRerollEligible ===")

test("eligible if in previous winners", function()
    local winners = {
        makeRoll(makePlayer("A", "guid-A"), 90, "mainspec"),
        makeRoll(makePlayer("B", "guid-B"), 80, "mainspec"),
    }
    assertTrue(Core.IsRerollEligible("guid-A", winners))
    assertTrue(Core.IsRerollEligible("guid-B", winners))
end)

test("not eligible if not in previous winners", function()
    local winners = { makeRoll(makePlayer("A", "guid-A"), 90, "mainspec") }
    assertFalse(Core.IsRerollEligible("guid-C", winners))
end)

test("not eligible with empty winners", function()
    assertFalse(Core.IsRerollEligible("guid-A", {}))
end)


-- ===================== SUMMARY =====================
print(string.format("\n=== Results: %d/%d passed, %d failed ===\n", passed, total, failed))
if failed > 0 then os.exit(1) end
