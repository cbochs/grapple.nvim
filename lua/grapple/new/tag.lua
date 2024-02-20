local Util = require("grapple.new.util")

---@class Tag
---@field path string absolute path
---@field cursor integer[] (1, 0)-based cursor position
local Tag = {}
Tag.__index = Tag

function Tag:new(path, cursor)
    return setmetatable({
        path = path,
        cursor = cursor,
    }, Tag)
end

---@return string? error
function Tag:select()
    local _, err = vim.uv.fs_access(self.path, "R")
    if err then
        return err
    end

    local short_path = vim.fn.fnamemodify(self.path, ":~:.")
    vim.cmd.edit(short_path)

    vim.api.nvim_win_set_cursor(0, self.cursor)
end

-- Implements Serialize
function Tag:into_table()
    ---@class TagFormat
    return {
        path = self.path,
        cursor = self.cursor,
    }
end

-- Implements Deserialize
---@param tbl TagFormat
---@return Tag, string? error
function Tag.from_table(tbl)
    return Tag:new(tbl.path, tbl.cursor), nil
end

return Tag
