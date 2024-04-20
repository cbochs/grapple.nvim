---@class grapple.tag
---@field path string absolute path
---@field name string | nil (optional) tag name
---@field cursor integer[] | nil (optional) (1, 0)-indexed cursor position
---@field frozen boolean
local Tag = {}
Tag.__index = Tag

---@param path string
---@param name? string
---@param cursor? integer[]
---@param frozen? boolean
function Tag:new(path, name, cursor, frozen)
    return setmetatable({
        path = path,
        name = name,
        cursor = cursor,
        frozen = frozen,
    }, self)
end

function Tag:update()
    if not self.frozen then
        self.cursor = vim.api.nvim_win_get_cursor(0)
    end
end

---@param command fun(path: string)
function Tag:select(command)
    command(self.path)

    if self.cursor then
        local current_cursor = vim.api.nvim_win_get_cursor(0)
        local last_line = vim.api.nvim_buf_line_count(0)

        -- Clamp the cursor to the last line
        local cursor = {
            math.min(self.cursor[1], last_line),
            self.cursor[2],
        }

        -- If the cursor has already been set, don't set again
        if self.frozen or (current_cursor[1] == 1 and current_cursor[2] == 0) then
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
