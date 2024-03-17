local Path = require("grapple.path")

---@class grapple.tag
---@field path string absolute path
---@field name string | nil (optional) tag name
---@field cursor integer[] | nil (optional) (1, 0)-indexed cursor position
local Tag = {}
Tag.__index = Tag

---@param path string
---@param name? string
---@param cursor? integer[]
function Tag:new(path, name, cursor)
    return setmetatable({
        path = path,
        name = name,
        cursor = cursor,
    }, self)
end

function Tag:update()
    self.cursor = vim.api.nvim_win_get_cursor(0)
end

---@param command? fun(path: string)
function Tag:select(command)
    local short_path = Path.fs_short(self.path)

    command = command or vim.cmd.edit
    command(short_path)

    if self.cursor then
        local current_cursor = vim.api.nvim_win_get_cursor(0)
        local last_line = vim.api.nvim_buf_line_count(0)

        -- Clamp the cursor to the last line
        local cursor = {
            math.min(self.cursor[1], last_line),
            self.cursor[2],
        }

        -- If the cursor has already been set, don't set again
        if current_cursor[1] == 1 or current_cursor[2] == 0 then
            pcall(vim.api.nvim_win_set_cursor, 0, cursor)
        end
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
