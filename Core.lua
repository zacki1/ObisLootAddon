--- Core.lua - Pure logic functions for ObisLootAddon
--- No WoW API dependencies. Testable standalone with busted or plain Lua.

local Core = {}

---@type {[integer|string]: string|integer}
Core.ROLL_TIERS = {
    [100] = "mainspec",
    [50]  = "offspec",
    [10]  = "transmog",
    mainspec = 100,
    offspec  = 50,
    transmog = 10,
}

---Parse a roll system message into structured data
---@param text string? The system message text
---@param pattern string The locale-specific pattern to match
---@return {name: string, rollValue: integer, rollArt: string}?
function Core.ParseRollText(text, pattern)
    if not text then return nil end
    local name, roll, max = string.match(text, pattern)
    if not name then return nil end
    local rollArt = Core.ROLL_TIERS[tonumber(max)]
    if not rollArt then return nil end
    return {
        name     = name,
        rollValue = tonumber(roll),
        rollArt  = rollArt,
    }
end

---Sort for rollArt (descending tier), then main > alt, then roll value (descending)
---@param left roll
---@param right roll
---@return boolean
function Core.SortRolls(left, right)
    if left.rollArt ~= right.rollArt then
        return Core.ROLL_TIERS[left.rollArt] > Core.ROLL_TIERS[right.rollArt]
    end
    if left.player.isMain ~= right.player.isMain then
        return left.player.isMain
    end
    return left.roll > right.roll
end

---Sort roster alphabetically by name (case-insensitive)
---@param left player
---@param right player
---@return boolean
function Core.SortRoster(left, right)
    return string.lower(left.name) < string.lower(right.name)
end

---Count how many items a player has won in a given tier
---@param playerGuid string
---@param rollArt string
---@param items itemDict
---@return integer
function Core.GetCountWins(playerGuid, rollArt, items)
    local count = 0
    for _, item in pairs(items) do
        for _, gewinner in pairs(item.gewinner) do
            if gewinner.player.guid == playerGuid and gewinner.rollArt == rollArt then
                count = count + 1
            end
        end
    end
    return count
end

---Determine winners from a pre-sorted roll list.
---Players with fewer prior wins in the same tier get priority.
---Returns multiple winners on a draw (equal roll value).
---@param sortedRolls roll[]
---@param count integer Number of items to award
---@param items itemDict All items (for win-count lookup)
---@return roll[]
function Core.ErmittleGewinner(sortedRolls, count, items)
    local gewinner = {}
    local i = 1
    while i <= #sortedRolls do
        local roll  = sortedRolls[i]
        local roll2 = sortedRolls[i + 1]

        if not roll2 or roll.rollArt ~= roll2.rollArt or roll.player.isMain ~= roll2.player.isMain then
            table.insert(gewinner, roll)
        elseif roll.rollArt == roll2.rollArt then
            local wins1 = Core.GetCountWins(roll.player.guid,  roll.rollArt, items)
            local wins2 = Core.GetCountWins(roll2.player.guid, roll2.rollArt, items)
            if wins1 < wins2 then
                table.insert(gewinner, roll)
            elseif wins1 == wins2 then
                if roll.roll == roll2.roll then
                    table.insert(gewinner, roll)
                    table.insert(gewinner, roll2)
                    i = i + 1
                elseif roll.roll > roll2.roll then
                    table.insert(gewinner, roll)
                end
            end
        end
        i = i + 1
        if #gewinner >= count then break end
    end
    return gewinner
end

---Check if a player has already rolled for the current item
---@param playerGuid string
---@param rolls roll[]
---@return boolean
function Core.HasAlreadyRolled(playerGuid, rolls)
    for _, roll in pairs(rolls) do
        if roll.player.guid == playerGuid then
            return true
        end
    end
    return false
end

---Check if a player is eligible for a reroll (was in previous winners)
---@param playerGuid string
---@param rerollGewinner roll[]
---@return boolean
function Core.IsRerollEligible(playerGuid, rerollGewinner)
    for _, winner in pairs(rerollGewinner) do
        if winner.player.guid == playerGuid then
            return true
        end
    end
    return false
end

---Check if a player's raid rank grants manager permissions
---@param raidRank integer? 0=member, 1=assist, 2=leader
---@return boolean
function Core.IsManager(raidRank)
    if not raidRank then return false end
    return raidRank >= 1
end

---Check if a loot item meets the quality threshold
---@param quality integer? Item quality (0=Poor..5=Legendary)
---@param threshold integer Minimum quality to consider relevant
---@return boolean
function Core.IsLootRelevant(quality, threshold)
    if not quality then return false end
    return quality >= threshold
end

-- Attach to addon in WoW environment
if ObisLootAddon then
    ObisLootAddon.Core = Core
end

return Core
