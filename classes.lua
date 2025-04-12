---@meta classes

---@class roll
---@field player player
---@field roll integer
---@field rollArt string

---@class itemRoll
---@field count integer
---@field rolls roll[]
---@field gewinner roll[]

---@class itemDict<itemLink, itemroll>: { [string]: itemRoll}


---@class id
---@field id integer
---@field items itemDict
---@field rerollArchive itemDict
---@field roster string[]

---@class player
---@field name string
---@field realm string
---@field guid string
---@field class string
---@field coloredName string
---@field isMain boolean

---@class roster<guid, player>: {[string]: player}