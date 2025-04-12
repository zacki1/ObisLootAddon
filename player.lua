local private = select(2,...)

---@class player
local Player = ObisLootAddon.Player

---Adds the player to the main roster list if not already in it
function ObisLootAddon:AddToMainRoster(player)
    if not player.guid then
        player = ObisLootAddon:GetPlayer(player.name)
    end
    if not  ObisLootAddonDB.MainRoster[player.guid] then
        ObisLootAddonDB.MainRoster[player.guid] = player
    end
    table.sort(ObisLootAddonDB.MainRoster, private.SortRoster)
end

---@return string playername
function Player:GetName() return self.name end
---@return string realmName
function Player:GetRealm() return self.realm end
---@return string class
function Player:GetClass() return self.class end
---@return string GUID
function Player:GetGUID() return self.guid end
---@return string coloredName
function Player:CreateColoredName() return RAID_CLASS_COLORS[self.class or "PRIEST"]:WrapTextInColorCode(self.name) --[[@as string]] end
---Returns playername in class color. If not saved already creates it
---@return string coloredName
function Player:GetColoredName()
    if not self.coloredName then self.coloredName = self:CreateColoredName() end
    return self.coloredName
end


local PLAYER_MT = {
	__index = Player,
	--- @param self player
	__tostring = function(self) return self.name end,
	--- @param a player|string
	--- @param b player|string
	__eq = function(a, b)
		if a.guid and b.guid then return a.guid == b.guid end
		return a == b end,
}


---Returns playerClass from roster or creates a new
---@param playerid string
---@return player player
function ObisLootAddon:GetPlayer(playerid)
    local player =  ObisLootAddonDB.MainRoster[playerid]
    if player then
        return setmetatable(player, PLAYER_MT)
    end

    -- Decide if input is a name or guid
	local guid
	if playerid and not strmatch(playerid, "Player%-") and strmatch(playerid, "%d?%d?%d?%d%-%x%x%x%x%x%x%x%x") then
		-- GUID without "Player-"
		guid = "Player-" .. playerid
	elseif playerid and strmatch(playerid, "Player%-%d?%d?%d?%d%-%x%x%x%x%x%x%x%x") then
		-- GUID with player
		guid = playerid
	elseif type(playerid) == "string" then
		-- Assume UnitName
		local name = Ambiguate(playerid, "none")
		guid = UnitGUID(name)
	else
		error(format("%s invalid player", tostring(playerid)), 2)
	end
    if not guid then error(format("Can't get GUID for %s", tostring(playerid)), 2) end
    player = {}
    local _,class,_,_,_,name,realm = GetPlayerInfoByGUID(guid)
    player.class = class
    player.name = name
    if realm == "" then realm = GetRealmName() end
    player.realm = realm
    player.guid = guid
    player.isMain = true
    return setmetatable(player, PLAYER_MT)
end



