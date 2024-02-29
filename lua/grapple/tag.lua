local Path = require("grapple.path")

---@class grapple.tag
---@field path string absolute path
---@field name string tag name
---@field cursor integer[] (1, 0)-indexed cursor position
local Tag = {}
Tag.__index = Tag

---@param path string
---@param cursor? integer[]
function Tag:new(path, name, cursor)
    return setmetatable({
        path = path,
        name = name,
        cursor = cursor or { 1, 0 },
    }, self)
end

function Tag:update()
    self.cursor = vim.api.nvim_win_get_cursor(0)
end

---@param command? function
function Tag:select(command)
    local short_path = Path.fs_short(self.path)

    command = command or vim.cmd.edit
    command(short_path)

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
        name = self.name,
        cursor = self.cursor,
    }

    return tbl
end

-- Implements Deserialize
---@param tbl grapple.tag.format
---@return grapple.tag | nil, string? error
function Tag.from_table(tbl)
    return Tag:new(tbl.path, tbl.name, tbl.cursor), nil
end

return Tag
