---@class grapple.tag
---@field path string absolute path
---@field cursor integer[] (1, 0)-based cursor position
local Tag = {}
Tag.__index = Tag

function Tag:new(path, cursor)
    return setmetatable({
        path = path,
        cursor = cursor,
    }, self)
end

function Tag:update(cursor)
    self.cursor = cursor
end

---@return string? error
function Tag:select()
    local _, err = vim.uv.fs_access(self.path, "R")
    if err then
        return err
    end

    local short_path = vim.fn.fnamemodify(self.path, ":~:.")
    if short_path == "" then
        short_path = self.path
    end
    vim.cmd.edit(short_path)

    local ok = pcall(vim.api.nvim_win_set_cursor, 0, self.cursor)
    if not ok then
        return string.format("invalid cursor location: %s", vim.inspect(self.cursor))
    end
end

-- Implements Serialize
function Tag:into_table()
    ---@class grapple.tag.format
    return {
        path = self.path,
        cursor = self.cursor,
    }
end

-- Implements Deserialize
---@param tbl grapple.tag.format
---@return grapple.tag, string? error
function Tag.from_table(tbl)
    return Tag:new(tbl.path, tbl.cursor), nil
end

return Tag
