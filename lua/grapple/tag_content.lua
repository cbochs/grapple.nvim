local Path = require("grapple.path")

---@class grapple.tag_content
---@field scope grapple.resolved_scope
---@field hook_fn grapple.hook_fn
---@field title_fn grapple.title_fn
local TagContent = {}
TagContent.__index = TagContent

---@param scope grapple.resolved_scope
---@param hook_fn? grapple.hook_fn
---@param title_fn? grapple.title_fn
---@return grapple.tag_content
function TagContent:new(scope, hook_fn, title_fn)
    return setmetatable({
        scope = scope,
        hook_fn = hook_fn,
        title_fn = title_fn,
    }, self)
end

---@return boolean
function TagContent:modifiable()
    return true
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
    if not self.hook_fn then
        return
    end

    local err = self.hook_fn(window)
    if err then
        return err
    end

    return nil
end

---@param window grapple.window
---@return string? error
---@diagnostic disable-next-line: unused-local
function TagContent:detach(window) end

---@param original grapple.window.entry
---@param parsed grapple.window.entry
---@return string? error
function TagContent:sync(original, parsed)
    local changes = self:diff(original, parsed)

    local err = self:apply_changes(changes)
    if err then
        return string.format("failed to apply changes: %s", err)
    end

    return nil
end

---@return grapple.window.entity[] | nil, string? error
function TagContent:entities()
    local tags, err = self.scope:tags()
    if not tags then
        return nil, err
    end

    return tags, nil
end

---@param path string
---@return string? icon, string? hl_group
local function get_icon(path)
    local ok, icons = pcall(require, "nvim-web-devicons")
    if not ok then
        error('The plugin "nvim-tree/nvim-web-devicons" is required')
    end

    local filename = vim.fn.fnamemodify(path, ":p:t")

    local icon, hl = icons.get_icon(filename)
    if not icon then
        if filename == "" then
            icon = ""
        else
            icon = ""
        end
    end

    return icon, hl
end

---@param tag grapple.tag
---@param index integer
---@return grapple.window.entry
function TagContent:create_entry(tag, index)
    local App = require("grapple.app")
    local app = App.get()

    -- A string representation of the index
    local id = string.format("/%03d", index)
    local rel_path = Path.fs_relative(self.scope.path, tag.path)

    local line, min_col, icon_highlight

    if app.settings.icons then
        local icon, icon_group = get_icon(tag.path)

        -- In compliance with "grapple" syntax
        line = string.format("%s %s  %s", id, icon, rel_path)
        min_col = assert(string.find(line, "%s%s")) + 1 -- width of id and icon

        if icon_group then
            ---@type grapple.vim.highlight
            icon_highlight = {
                hl_group = icon_group,
                line = index - 1,
                col_start = assert(string.find(line, "%s")),
                col_end = assert(string.find(line, "%s%s")),
            }
        end
    else
        -- In compliance with "grapple" syntax
        line = string.format("%s %s", id, rel_path)
        min_col = assert(string.find(line, "%s")) -- width of id
    end

    ---@type grapple.window.entry
    local entry = {
        ---@class grapple.tag.content.data
        data = {
            path = tag.path,
            name = tag.name,
            cursor = tag.cursor,
        },

        line = line,
        index = index,
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
                virt_text = tag.name and { { tag.name } },
            },
        },
    }

    return entry
end

---@param line string
---@return grapple.window.parsed_entry
function TagContent:parse_line(line)
    local App = require("grapple.app")
    local app = App.get()

    ---@diagnostic disable-next-line: unused-local
    local id, icon, index, path

    if app.settings.icons then
        ---@diagnostic disable-next-line: unused-local
        id, icon, path = string.match(line, "^/(%d+) (%S+)  (%S*)")
    else
        id, path = string.match(line, "^/(%d+) (%S*)")
    end

    if id then
        index = assert(tonumber(id))
        path = path
    else
        -- Parse as a new entry when an ID is not present
        index = nil
        path = line
    end

    -- Remove whitespace around path before parsing
    path = vim.trim(path)

    -- Don't parse an empty path or line
    if path == "" then
        ---@type grapple.window.parsed_entry
        local entry = {
            data = {
                path = nil,
            },
            line = line,
            index = index,
        }

        return entry
    end

    -- We shouldn't try to join with the scope path if:
    -- 1. The path starts with "~", "./", or "../"
    -- 2. The path is absolute or a URI
    if not Path.is_joinable(path) then
        path = Path.join(self.scope.path, path)
    end

    path = Path.fs_absolute(path)

    ---@type grapple.window.parsed_entry
    local entry = {
        data = {
            path = path,
        },
        line = line,
        index = index,
    }

    return entry
end

---@class grapple.tag.content.change
---@field action "insert" | "move" | "remove"
---@field priority integer
---@field opts grapple.tag.container.insert | grapple.tag.container.move | grapple.tag.container.get

---@param original grapple.window.entry[]
---@param modified grapple.window.parsed_entry[]
---@return grapple.tag.content.change[]
function TagContent:diff(original, modified)
    ---@type grapple.tag.content.change[]
    local changes = {}

    -- Perform a naive diff. Assume all original paths have been removed and
    -- all modified lines are inserted. This makes it easier to resolve
    -- differences and guarantees that the content and container tags are
    -- the same. Could be improved if performance becomes a problem

    ---@param entry grapple.window.parsed_entry
    local function has_path(entry)
        return entry.data.path
    end

    for i, entry in ipairs(vim.tbl_filter(has_path, modified)) do
        ---@type grapple.tag.content.data
        local data = entry.data

        if not data.path then
            goto continue
        end

        local name, cursor
        if entry.index then
            local original_entry = original[entry.index]

            ---@type grapple.tag.content.data
            local original_data = original_entry.data

            if original_data.path == data.path then
                name = original_data.name
                cursor = original_data.cursor
            end
        end

        table.insert(changes, {
            action = "insert",
            opts = {
                path = entry.data.path,
                name = name,
                cursor = cursor,
                index = i,
            },
        })

        ::continue::
    end

    return changes
end

---@param changes grapple.tag.content.change[]
---@return string? error
function TagContent:apply_changes(changes)
    return self.scope:enter(function(container)
        container:clear()

        -- TODO: should probably store and return errors
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
end

---@param action grapple.action
---@param opts? grapple.action.options
---@return string? error
function TagContent:perform(action, opts)
    opts = vim.tbl_extend("force", opts or {}, {
        scope = self.scope,
    })

    return action(opts)
end

return TagContent
