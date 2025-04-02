---@meta classes

---@class roll
---@field player string
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