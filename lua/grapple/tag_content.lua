local Path = require("grapple.path")
local Util = require("grapple.util")

---@class grapple.tag.content
---@field entries grapple.tag.content.entry[]
---@field scope grapple.scope.resolved
---@field hook_fn grapple.tag.content.hook_fn
---@field title_fn grapple.tag.content.title_fn
local TagContent = {}
TagContent.__index = TagContent

---@alias grapple.tag.content.hook_fn fun(window: grapple.window): string?
---@alias grapple.tag.content.title_fn fun(scope: grapple.scope.resolved): string

---@param scope grapple.scope.resolved
---@param hook_fn grapple.tag.content.hook_fn
---@param title_fn? grapple.tag.content.title_fn
---@return grapple.tag.content
function TagContent:new(scope, hook_fn, title_fn)
    return setmetatable({
        entries = {},
        scope = scope,
        hook_fn = hook_fn,
        title_fn = title_fn,
    }, self)
end

---@return string id
function TagContent:id()
    return self.scope.id
end

---@return string | nil title
function TagContent:title()
    if not self.title_fn then
        return
    end

    return self.title_fn(self.scope)
end

---@param window grapple.window
---@return string? error
function TagContent:attach(window)
    local err = self.hook_fn(window)
    if err then
        return err
    end

    return nil
end

---@param buf_id integer
---@return string? error
function TagContent:detach(buf_id)
    local err = self:sync(buf_id)
    if err then
        return err
    end

    return nil
end

---@param tag grapple.tag
---@param index integer
---@return grapple.tag.content.entry
function TagContent:update_entry(tag, index)
    ---@param name string
    ---@return string? icon, string? hl_group
    local function get_icon(name)
        local ok, icons = pcall(require, "nvim-web-devicons")
        if not ok then
            return nil, nil
        end

        local icon, hl = icons.get_icon(name)
        if not icon then
            if name == "" then
                icon = ""
            else
                icon = ""
            end
        end

        return icon, hl
    end

    local id = string.format("/%03d", index)
    local name = vim.fn.fnamemodify(tag.path, ":p")
    local rel_path = Path.relative(self.scope.path, tag.path)

    local text, min_col, icon_highlight
    local use_icons = require("grapple.app").get().settings.icons
    if use_icons then
        ---@diagnostic disable-next-line: param-type-mismatch
        local icon, icon_group = get_icon(name)

        -- In compliance with "grapple" syntax
        text = string.format("%s %s  %s", id, icon, rel_path)
        min_col = string.find(text, "%s%s") + 1 -- width of id and icon

        if icon_group then
            ---@type grapple.vim.highlight
            icon_highlight = {
                hl_group = icon_group,
                line = index - 1,
                col_start = assert(string.find(text, "%s")),
                col_end = assert(string.find(text, "%s%s")),
            }
        end
    else
        -- In compliance with "grapple" syntax
        text = string.format("%s %s", id, rel_path)
        min_col = string.find(text, "%s") -- width of id
    end

    ---@class grapple.tag.content.entry
    local entry = {
        tag = tag,

        id = id,
        path = tag.path,
        line = text,
        min_col = min_col,

        ---@type grapple.vim.highlight[]
        highlights = { icon_highlight },

        ---@type grapple.vim.extmark
        mark = {
            line = index - 1,
            col = 0,
            opts = {
                sign_text = string.format("%d", index),
                invalidate = true,
            },
        },
    }

    return entry
end

---@return string? error
function TagContent:update()
    local tags, err = self.scope:tags()
    if not tags then
        return err
    end

    self.entries = {}
    for i, tag in ipairs(tags) do
        local entry = self:update_entry(tag, i)
        table.insert(self.entries, entry)
    end
end

---@param buf_id integer
---@param ns_id integer
function TagContent:render(buf_id, ns_id)
    local function lines(entry)
        return entry.line
    end

    local function marks(entry)
        return entry.mark
    end

    local function highlights(entry)
        return entry.highlights
    end

    vim.api.nvim_buf_set_lines(buf_id, 0, -1, true, vim.tbl_map(lines, self.entries))

    for _, mark in ipairs(vim.tbl_map(marks, self.entries)) do
        vim.api.nvim_buf_set_extmark(buf_id, ns_id, mark.line, mark.col, mark.opts)
    end

    for _, entry_hl in ipairs(vim.tbl_map(highlights, self.entries)) do
        for _, hl in ipairs(entry_hl) do
            vim.api.nvim_buf_add_highlight(buf_id, ns_id, hl.hl_group, hl.line, hl.col_start, hl.col_end)
        end
    end
end

---@param buf_id integer
---@return string? error
function TagContent:sync(buf_id)
    local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)

    local parsed = self:parse(lines)
    local changes = self:diff(self.entries, parsed)

    local err = self:apply_changes(changes)
    if err then
        return string.format("failed to apply changes: %s", err)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = self:update()
    if err then
        return err
    end

    return nil
end

---A strict optional subset of grapple.tag.content.entry
---@class grapple.tag.content.parsed_entry
---@field id integer | nil
---@field path string | nil

---@param line string
---@return grapple.tag.content.parsed_entry
function TagContent:parse_line(line)
    ---@type grapple.tag.content.parsed_entry
    local entry = {
        id = nil,
        path = nil,
        line = line,
    }

    local use_icons = require("grapple.app").get().settings.icons
    if use_icons then
        entry.id, _, entry.path = string.match(line, "^/(%d+) (.+)  (.*)$")
    else
        entry.id, entry.path = string.match(line, "^/(%d+) (.*)$")
    end

    if entry.id then
        entry.id = tonumber(entry.id)
    else
        -- Parse as a new entry when an ID is not present
        entry.path = line
    end

    -- Don't parse an empty path or line
    if entry.path == "" then
        entry.path = nil
        return entry
    end

    -- Only parse using the scope when the path does not start with either "./" or "../"
    if not vim.startswith(entry.path, "../") and not vim.startswith(entry.path, "./") then
        entry.path = Path.join(self.scope.path, entry.path)
    end

    entry.path = Path.absolute(entry.path)

    return entry
end

---@param lines string[]
---@return grapple.tag.content.parsed_entry[]
function TagContent:parse(lines)
    ---@diagnostic disable-next-line: redefined-local
    local lines = vim.tbl_filter(Util.is_empty, lines)

    ---@type grapple.tag.content.parsed_entry[]
    local parsed = {}

    for _, line in ipairs(lines) do
        local entry = self:parse_line(line)
        table.insert(parsed, entry)
    end

    return parsed
end

function TagContent:minimum_column(line)
    local parsed = self:parse_line(line)
    if not parsed then
        return 0
    end

    if not parsed.id then
        return 0
    end

    local entry = self.entries[parsed.id]
    if not entry then
        error("id should be the index of a valid entry")
    end

    return entry.min_col
end

---@class grapple.tag.content.change
---@field action "insert" | "move" | "remove"
---@field priority integer
---@field opts grapple.tag.container.insert | grapple.tag.container.move | grapple.tag.container.get

---@param original grapple.tag.content.entry[]
---@param modified grapple.tag.content.parsed_entry[]
---@return grapple.tag.content.change[]
function TagContent:diff(original, modified)
    ---@type grapple.tag.content.change[]
    local changes = {}

    -- Perform a naive diff. Assume all original paths have been removed and
    -- all modified lines are inserted. This makes it easier to resolve
    -- differences and guarantees that the content and container tags are
    -- the same. Could be improved if performance becomes a problem

    ---@param entry grapple.tag.content.parsed_entry
    local function filter_empty(entry)
        return entry.path
    end

    ---@type table<string, integer>
    local original_lookup = {}

    for i, entry in ipairs(original) do
        original_lookup[entry.path] = i
    end

    for i, entry in ipairs(vim.tbl_filter(filter_empty, modified)) do
        local path = entry.path
        local index = original_lookup[path]
        local original_entry = self.entries[index]

        table.insert(changes, {
            action = "insert",
            opts = {
                path = entry.path,
                cursor = original_entry and original_entry.tag.cursor,
                index = i,
            },
        })
    end

    return changes
end

---@param changes grapple.tag.content.change[]
---@return string? error
function TagContent:apply_changes(changes)
    return self.scope:enter(function(container)
        container:clear()

        for _, change in ipairs(changes) do
            if change.action == "insert" then
                ---@diagnostic disable-next-line: param-type-mismatch
                container:insert(change.opts)
            elseif change.action == "move" then
                ---@diagnostic disable-next-line: param-type-mismatch
                container:move(change.opts)
            elseif change.action == "remove" then
                ---@diagnostic disable-next-line: param-type-mismatch
                container:remove(change.opts)
            else
                error(string.format("unsupported action: %s", change.action))
            end
        end
    end)
end

---@param action grapple.action
---@param opts? grapple.action.options
---@return string? error
function TagContent:perform(action, opts)
    return action(self.scope, opts)
end

return TagContent
