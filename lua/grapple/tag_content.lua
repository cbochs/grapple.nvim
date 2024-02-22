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

---@return string title
function TagContent:title()
    if self.title_fn then
        return self.title_fn(self.scope)
    end

    ---@type string
    ---@diagnostic disable-next-line: assign-type-mismatch
    local title = vim.fn.fnamemodify(self.scope.path, ":~")

    return title
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

---@return string? error
function TagContent:update()
    local tags, err = self.scope:tags()
    if err then
        return err
    end

    ---@param tag grapple.tag
    ---@return string icon, string? hl_group
    local function get_icon(tag)
        local icons = require("nvim-web-devicons")
        local name = vim.fn.fnamemodify(tag.path, ":t")
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

    -- In compliance with "grapple" syntax
    ---@param index integer
    ---@param tag grapple.tag
    ---@return string
    local function into_line(index, tag)
        local id = string.format("/%03d", index)
        local icon = get_icon(tag)
        local rel_path = Util.relative(tag.path, self.scope.path)

        return string.format("%s %s  %s", id, icon, rel_path)
    end

    ---@param index integer
    ---@return grapple.vim.extmark
    local function into_mark(index)
        ---See :h vim.api.nvim_buf_set_extmark
        ---@class grapple.vim.extmark
        local mark = {
            line = index - 1,
            col = 0,
            opts = {
                sign_text = string.format("%d", index),
            },
        }

        return mark
    end

    self.entries = {}

    for i, tag in ipairs(tags) do
        ---@class grapple.tag.content.entry
        table.insert(self.entries, {
            path = tag.path,
            line = into_line(i, tag),
            mark = into_mark(i),
        })
    end

    return nil
end

---@param buf_id integer
---@param ns_id integer
---@return string? error
function TagContent:render(buf_id, ns_id)
    ---@param entry grapple.tag.content.entry
    local function lines(entry)
        return entry.line
    end

    ---@param entry grapple.tag.content.entry
    local function marks(entry)
        return entry.mark
    end

    vim.api.nvim_buf_set_lines(buf_id, 0, -1, true, vim.tbl_map(lines, self.entries))

    for _, mark in ipairs(vim.tbl_map(marks, self.entries)) do
        vim.api.nvim_buf_set_extmark(buf_id, ns_id, mark.line, mark.col, mark.opts)
    end

    return nil
end

---@param buf_id integer
---@return string? error
function TagContent:sync(buf_id)
    ---@param entry grapple.tag.content.entry
    local function paths(entry)
        return entry.path
    end

    local original_paths = vim.tbl_map(paths, self.entries)

    local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
    local modified_paths, errs = self:parse(lines)
    if #errs > 0 then
        return string.format("failed to parse lines:\n%s", table.concat(errs, "\n"))
    end

    local changes, errs = self:diff(original_paths, modified_paths)
    if #errs > 0 then
        return table.concat(errs, "\n")
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = self:apply_changes(changes)
    if err then
        return string.format("failed to apply changes:\n%s", table.concat(errs, "\n"))
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = self:update()
    if err then
        return err
    end

    return nil
end

---@param lines string[]
---@return string[] paths, string[] errors
function TagContent:parse(lines)
    local paths = {}
    local errors = {}

    for _, line in ipairs(lines) do
        if line == "" then
            goto continue
        end

        local path, err = self:parse_line(line)
        if err then
            table.insert(errors, err)
        else
            table.insert(paths, path)
        end

        ::continue::
    end

    return paths, errors
end

---@param line string
---@return string path, string? error
function TagContent:parse_line(line)
    if line == "" then
        return "", "empty line"
    end

    local id, _, path = string.match(line, "^/(%d+) (.+)  (.+)$")

    -- If an ID is not present, parse as a new entry
    if not id then
        path = line
    end

    -- If a path starts with "./" or "../", parse without scope path
    local abs_path, err
    if vim.startswith(path, "../") or vim.startswith(path, "./") then
        abs_path, err = Util.absolute(path)
    else
        abs_path, err = Util.absolute(Util.join(self.scope.path, path))
    end

    if err then
        return "", err
    end

    return abs_path, nil
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

---@param action grapple.action
---@param opts? grapple.action.options
---@return string? error
function TagContent:perform(action, opts)
    local err = action(self.scope, opts)
    if err then
        return err
    end

    return nil
end

return TagContent
