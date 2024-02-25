local Util = require("grapple.util")

---@class grapple.tag
---@field path string absolute path
---@field cursor integer[] (1, 0)-indexed cursor position
local Tag = {}
Tag.__index = Tag

---@param path string
---@param cursor? integer[]
function Tag:new(path, cursor)
    return setmetatable({
        path = path,
        cursor = cursor or { 1, 0 },
    }, self)
end

---@return boolean success, string? error
function Tag:update()
    self.cursor = vim.api.nvim_win_get_cursor(0)

    return true, nil
end

---@return string? error
function Tag:select()
    if not Util.exists(self.path) then
        return string.format("tag path does not exist", self.path)
    end

    local short_path = Util.short(self.path)
    vim.cmd.edit(short_path)

    -- If the cursor has already been set, update instead
    local current_cursor = vim.api.nvim_win_get_cursor(0)
    if current_cursor[1] > 1 or current_cursor[2] > 0 then
        self.cursor = current_cursor
    else
        vim.api.nvim_win_set_cursor(0, self.cursor)
    end
end

-- Implements Serialize
function Tag:into_table()
    ---@class grapple.tag.format
    local tbl = {
        path = self.path,
        cursor = self.cursor,
    }

    return tbl
end

-- Implements Deserialize
---@param tbl grapple.tag.format
---@return grapple.tag | nil, string? error
function Tag.from_table(tbl)
    return Tag:new(tbl.path, tbl.cursor), nil
end

return Tag
