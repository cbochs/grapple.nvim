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
    local rel_path = Util.relative(tag.path, self.scope.path)

    -- TODO: it would be cool if invalid paths were highlighted somehow
    -- Like if the extmark in the sign column was red or something

    -- In compliance with "grapple" syntax
    local text, min_col, icon_highlight
    local use_icons = require("grapple.app").get().settings.icons
    if use_icons then
        ---@diagnostic disable-next-line: param-type-mismatch
        local icon, icon_group = get_icon(name)

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
        text = string.format("%s %s", id, rel_path)
        min_col = string.find(text, "%s") -- width of id
    end

    ---@class grapple.tag.content.entry
    local entry = {
        tag = tag,

        id = id,
        name = name,
        min_col = min_col,

        ---@type grapple.vim.line
        line = {
            index = index - 1,
            text = text,
        },

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

---@param entry grapple.tag.content.entry
---@param buf_id integer
---@param ns_id integer
function TagContent:render_line(entry, buf_id, ns_id)
    vim.api.nvim_buf_set_lines(buf_id, entry.line.index, entry.line.index, true, { entry.line.text })

    if entry.mark then
        vim.api.nvim_buf_set_extmark(buf_id, ns_id, entry.mark.line, entry.mark.col, entry.mark.opts)
    end

    for _, hl in ipairs(entry.highlights) do
        vim.api.nvim_buf_add_highlight(buf_id, ns_id, hl.hl_group, hl.line, hl.col_start, hl.col_end)
    end
end

---@param buf_id integer
---@param ns_id integer
function TagContent:render(buf_id, ns_id)
    for _, entry in ipairs(self.entries) do
        self:render_line(entry, buf_id, ns_id)
    end
end

---@param buf_id integer
---@return string? error
function TagContent:sync(buf_id)
    local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
    local parsed, errs = self:parse(lines)
    if #errs > 0 then
        return string.format("failed to parse:\n%s", table.concat(errs, "\n"))
    end

    ---@diagnostic disable-next-line: redefined-local
    local changes, errs = self:diff(self.entries, parsed)
    if #errs > 0 then
        return string.format("failed to diff:\n%s", table.concat(errs, "\n"))
    end

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
---@field id string | nil
---@field path string

---@param line string
---@return grapple.tag.content.parsed_entry | nil, string? error
function TagContent:parse_line(line)
    if line == "" then
        return nil, "empty line"
    end

    local id, path
    local use_icons = require("grapple.app").get().settings.icons
    if use_icons then
        id, _, path = string.match(line, "^/(%d+) (.+)  (.+)$")
    else
        id, path = string.match(line, "^/(%d+) (.+)$")
    end

    -- If an ID is not present, parse as a new entry
    if not id then
        path = line
    end

    -- Only parse using the scope when the path does not start with either "./" or "../"
    if not vim.startswith(path, "../") and not vim.startswith(path, "./") then
        path = Util.join(self.scope.path, path)
    end

    local abs_path, err = Util.absolute(path)
    if not abs_path then
        return nil, err
    end

    local entry = {
        id = tonumber(id),
        path = abs_path,
    }

    return entry, nil
end

---@param lines string[]
---@return grapple.tag.content.parsed_entry[], string[] errors
function TagContent:parse(lines)
    local function filter_empty(line)
        return line ~= ""
    end

    ---@diagnostic disable-next-line: redefined-local
    local lines = vim.tbl_filter(filter_empty, lines)

    ---@type grapple.tag.content.parsed_entry[]
    local parsed = {}

    ---@type string[]
    local errors = {}

    for _, line in ipairs(lines) do
        local entry, err = self:parse_line(line)
        if not entry then
            table.insert(errors, err)
        else
            table.insert(parsed, entry)
        end
    end

    return parsed, errors
end

function TagContent:minimum_column(line)
    local parsed, _ = self:parse_line(line)
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
---@field opts grapple.tag.container.insert | grapple.tag.container.move | grapple.tag.container.remove

---@param original grapple.tag.content.entry[]
---@param modified grapple.tag.content.parsed_entry[]
---@return grapple.tag.content.change[], string[] errors
function TagContent:diff(original, modified)
    ---@type grapple.tag.content.change[]
    local changes = {}

    ---@type string[]
    local errors = {}

    -- Perform a naive diff. Assume all original paths have been removed and
    -- all modified lines are inserted. This makes it easier to resolve
    -- differences and guarantees that the content and container tags are
    -- the same. Could be improved if performance becomes a problem

    ---@type table<string, integer>
    local original_lookup = {}

    for i, entry in ipairs(original) do
        original_lookup[entry.tag.path] = i
    end

    for i, entry in ipairs(modified) do
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

    return changes, errors
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
