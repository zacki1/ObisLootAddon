---@meta classes
---@class roster<guid, player>: {[string]: player}

---@class roll
---@field player player
---@field roll integer
---@field rollArt string

---@class tradeInfo
---@field itemLink string
---@field winnerGuid string
---@field traded boolean
---@field tradedAt string?

---@class itemRoll
---@field count integer
---@field rolls roll[]
---@field gewinner roll[]
---@field traded {[string]: string}?

---@class itemDict<itemLink, itemroll>: { [string]: itemRoll}


---@class id
---@field id integer
---@field raidId string?
---@field zone string?
---@field difficulty string?
---@field date string?
---@field items itemDict
---@field rerollArchive itemDict
---@field roster roster

---@class player
---@field name string
---@field realm string
---@field guid string
---@field class string
---@field coloredName string
---@field isMain boolean

---@class raidHistory
---@field raidId string
---@field zone string
---@field difficulty string
---@field date string
---@field items itemDict
---@field roster roster