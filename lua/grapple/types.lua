---@class Serializable
local Serializable = {}

---@return table
function Serializable:into_table()
    return {}
end

---@class Deserializable
local Deserializable = {}

---@generic T
---@param tbl table
---@return T obj, string? error
---@diagnostic disable-next-line: unused-local
function Deserializable.from_table(tbl)
    return {}, ""
end

---See :h nvim_open_win
---@class grapple.vim.win_opts
---@field relative? "editor" | "win" | "cursor" | "mouse"
---@field win? integer
---@field anchor? "NW" | "NW" | "SW" | "SE"
---@field width? integer | float either a fixed width or a decimal percentage
---@field height? integer | float either a fixed width or a decimal percentage
---@field bufpos? integer[]
---@field row? integer | float
---@field col? integer | float
---@field focusable? boolean
---@field external? boolean
---@field zindex? integer
---@field style? "minimal"
---@field border? "none" | "single" | "double" | "rounded" | "solid" | "shadow" | string[] default is "none"
---@field title? string | fun(): string
---@field title_pos? "left" | "center" | "right" default is "left"
---@field footer? string | fun(): string
---@field footer_pos? "left" | "center" | "right" default is "left"
---@field noautocmd? boolean
---@field fixed? boolean
---@field hide? boolean
---@field vertical? boolean
---@field split? "left" | "right" | "above" | "below"
