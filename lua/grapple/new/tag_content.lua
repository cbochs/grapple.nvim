local Util = require("grapple.new.util")

---@class TagContent
---@field scope ResolvedScope
---@field entries table[]
local TagContent = {}
TagContent.__index = TagContent

---@param scope ResolvedScope
---@return TagContent
function TagContent:new(scope)
    return setmetatable({
        scope = scope,
        entries = nil,
    }, TagContent)
end

---@return string? error
function TagContent:select(index)
    return self.scope:enter(function(container)
        local tag, err = container:get({ index = index })
        if err then
            return err
        end

        tag:select()
    end)
end

---@param buf_id integer
---@param ns_id integer
---@return string? error
function TagContent:render(buf_id, ns_id)
    local tags, err = self.scope:tags()
    if err then
        return err
    end

    self.entries = {}

    for i, tag in ipairs(tags) do
        table.insert(self.entries, {
            path = tag.path,
            line = Util.relative(tag.path, self.scope.path),
            mark = {
                line = i - 1,
                col = 0,
                opts = {
                    sign_text = string.format("%s", i),
                },
            },
        })
    end

    local function lines(entry)
        return entry.line
    end

    local function marks(entry)
        return entry.mark
    end

    vim.api.nvim_buf_set_lines(buf_id, 0, 0, false, vim.tbl_map(lines, self.entries))

    for _, mark in ipairs(vim.tbl_map(marks, self.entries)) do
        vim.api.nvim_buf_set_extmark(buf_id, ns_id, mark.line, mark.col, mark.opts)
    end

    return nil
end

---@param buf_id integer
---@return string? error
function TagContent:reconcile(buf_id)
    local original_paths = vim.tbl_map(function(entry)
        return entry.path
    end, self.entries)

    local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)

    local modified_paths = vim.tbl_map(
        function(line)
            return Util.absolute(line)
        end,
        vim.tbl_filter(function(line)
            return line ~= ""
        end, lines)
    )

    local changes, err = self:diff(original_paths, modified_paths)
    if #err > 0 then
        -- TODO: better error handling
        return vim.inspect(err)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = self:apply_changes(changes)
    if err then
        return err
    end

    return nil
end

---@class Change
---@field action "insert" | "move" | "remove"
---@field path string
---@field index integer

---@param original string[]
---@param modified string[]
---@return Change[], string[] errors
function TagContent:diff(original, modified)
    local changes = {}
    local errors = {}

    local original_lookup = {}
    for _, path in ipairs(original) do
        original_lookup[path] = true
    end

    local modified_lookup = {}
    for _, path in ipairs(modified) do
        if modified_lookup[path] then
            table.insert(errors, string.format("duplicate: %s", path))
        end
        modified_lookup[path] = true
    end

    for i, path in ipairs(modified) do
        if not original_lookup[path] then
            table.insert(changes, {
                action = "insert",
                path = path,
                index = i,
            })
        end
    end

    for i, path in ipairs(original) do
        if vim.tbl_contains(modified, path) then
            table.insert(changes, {
                action = "move",
                path = path,
                index = i,
            })
        else
            table.insert(changes, {
                action = "remove",
                path = path,
            })
        end
    end

    return changes, errors
end

---@param changes Change[]
---@return string? error
function TagContent:apply_changes(changes)
    local err = self.scope:enter(function(container)
        -- for _, change in ipairs(changes) do
        --     if change.action == "insert" then
        --         container:insert({
        --             path = change.path,
        --             cursor = { 1, 0 },
        --             index = change.index,
        --         })
        --     elseif change.action == "move" then
        --         container:move({
        --             path = change.path,
        --             index = change.index,
        --         })
        --     elseif change.action == "remove" then
        --         container:remove({
        --             path = change.path,
        --         })
        --     end
        -- end
    end)
    if err then
        return err
    end

    return nil
end

return TagContent
