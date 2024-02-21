local Util = require("grapple.util")

---@class grapple.tag.content
---@field scope grapple.scope.resolved
---@field entries grapple.tag.content.entry[]
local TagContent = {}
TagContent.__index = TagContent

---@param scope grapple.scope.resolved
---@return grapple.tag.content
function TagContent:new(scope)
    return setmetatable({
        scope = scope,
        entries = {},
    }, self)
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

---@return grapple.vim.quickfix[]
function TagContent:quickfix()
    ---@param entry grapple.tag.content.entry
    local function quickfix(entry)
        return entry.quickfix
    end

    return vim.tbl_map(quickfix, self.entries)
end

---@return string? error
function TagContent:update()
    local tags, err = self.scope:tags()
    if err then
        return err
    end

    self.entries = {}

    for i, tag in ipairs(tags) do
        ---@class grapple.tag.content.entry
        table.insert(self.entries, {
            path = tag.path,
            line = Util.relative(tag.path, self.scope.path),

            ---See :h vim.api.nvim_buf_set_extmark
            ---@class grapple.vim.extmark
            mark = {
                line = i - 1,
                col = 0,
                opts = {
                    sign_text = string.format("%s", i),
                },
            },

            ---See :h vim.fn.setqflist
            ---@class grapple.vim.quickfix
            quickfix = {
                filename = tag.path,
                lnum = tag.cursor[1],
                col = tag.cursor[2] + 1,
                text = Util.relative(tag.path, self.scope.path),
            },
        })
    end

    return nil
end

---@param buf_id integer
---@param ns_id integer
function TagContent:render(buf_id, ns_id)
    ---@param entry grapple.tag.content.entry
    local function lines(entry)
        return entry.line
    end

    ---@param entry grapple.tag.content.entry
    local function marks(entry)
        return entry.mark
    end

    vim.api.nvim_buf_set_lines(buf_id, 0, 0, false, vim.tbl_map(lines, self.entries))

    for _, mark in ipairs(vim.tbl_map(marks, self.entries)) do
        vim.api.nvim_buf_set_extmark(buf_id, ns_id, mark.line, mark.col, mark.opts)
    end
end

---@param buf_id integer
---@return string? error
function TagContent:reconcile(buf_id)
    local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)

    local original_paths = vim.tbl_map(function(entry)
        return entry.path
    end, self.entries)

    local modified_paths = vim.tbl_map(
        function(line)
            return Util.absolute(Util.join(self.scope.path, line))
        end,
        vim.tbl_filter(function(line)
            return line ~= ""
        end, lines)
    )

    local changes, err = self:diff(original_paths, modified_paths)
    if #err > 0 then
        return table.concat(err, "\n")
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = self:apply_changes(changes)
    if err then
        return err
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = self:update()
    if err then
        return err
    end

    return nil
end

---@class grapple.tag.content.change
---@field action "insert" | "move" | "remove"
---@field opts grapple.tag.container.insert | grapple.tag.container.move | grapple.tag.container.remove

---@param original string[]
---@param modified string[]
---@return grapple.tag.content.change[], string[] errors
function TagContent:diff(original, modified)
    local changes = {}
    local errors = {}

    -- Perform a naive diff. Assume all original paths have been removed and
    -- all modified lines are inserted. This makes it easier to resolve
    -- differences and guarantees that the content and container tags are
    -- the same.

    for _, path in ipairs(original) do
        table.insert(changes, {
            action = "remove",
            opts = {
                path = path,
            },
        })
    end

    local modified_lookup = {}
    for i, path in ipairs(modified) do
        if modified_lookup[path] then
            table.insert(errors, string.format("duplicate path: %s", path))
            goto continue
        end

        modified_lookup[path] = true
        table.insert(changes, {
            action = "insert",
            opts = {
                path = path,
                cursor = { 1, 0 },
                index = i,
            },
        })

        ::continue::
    end

    return changes, errors
end

---@param changes grapple.tag.content.change[]
---@return string? error
function TagContent:apply_changes(changes)
    local err = self.scope:enter(function(container)
        for _, change in ipairs(changes) do
            if change.action == "insert" then
                ---@diagnostic disable-next-line: param-type-mismatch
                container:insert(change.opts)
            elseif change.action == "remove" then
                ---@diagnostic disable-next-line: param-type-mismatch
                container:remove(change.opts)
            else
                error(string.format("unsupported action: %s", change.action))
            end
        end
    end)
    if err then
        return err
    end

    return nil
end

return TagContent
