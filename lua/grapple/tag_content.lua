local Path = require("grapple.path")

---@class grapple.tag_content
---@field scope grapple.resolved_scope
---@field hook_fn grapple.hook_fn
---@field title_fn grapple.title_fn
---@field current_selection string | nil path of the current buffer
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
        current_selection = nil,
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
    if self.hook_fn then
        local err = self.hook_fn(window)
        if err then
            return err
        end
    end

    -- Get the path for the buffer in the current window, not the Grapple window
    self.current_selection = window:alternate_path()

    return nil
end

---@param window grapple.window
---@return string? error
---@diagnostic disable-next-line: unused-local
function TagContent:detach(window)
    self.current_selection = nil
end

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

    local entities = {}

    for _, tag in ipairs(tags) do
        ---@class grapple.tag_content.entity
        local entity = {
            tag = tag,
            current = tag.path == self.current_selection,
        }

        table.insert(entities, entity)
    end

    return entities, nil
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

---@param entity grapple.tag_content.entity
---@param index integer
---@return grapple.window.entry
function TagContent:create_entry(entity, index)
    local App = require("grapple.app")
    local app = App.get()

    local tag = entity.tag

    -- A string representation of the index
    local id = string.format("/%03d", index)
    local rel_path = Path.fs_relative(self.scope.path, tag.path)

    -- In compliance with "grapple" syntax
    local line = string.format("%s %s", id, rel_path)
    local min_col = assert(string.find(line, "%s")) -- width of id

    local sign_highlight, icon_highlight

    if not app.settings.status then
        -- Do not set highlight
    elseif entity.current then
        sign_highlight = "GrappleCurrent"
    elseif not Path.exists(tag.path) then
        sign_highlight = "GrappleNoExist"
    end

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
    end

    ---@type grapple.window.entry
    local entry = {
        ---@class grapple.tag_content.data
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
                sign_hl_group = sign_highlight,
                virt_text = tag.name and { { tag.name } },

                -- TODO: requires nvim-0.10
                -- invalidate = true,
            },
        },
    }

    return entry
end

---@param line string
---@param original_entries grapple.window.entry[]
---@return grapple.window.parsed_entry
function TagContent:parse_line(line, original_entries)
    local App = require("grapple.app")
    local app = App.get()

    ---@diagnostic disable-next-line: unused-local
    local icon

    local id, index, path, original_entry

    -- In compliance with "grapple" syntax
    if app.settings.icons then
        ---@diagnostic disable-next-line: unused-local
        id, icon, path = string.match(line, "^/(%d+) (%S+)  %s*(%S*)")
    else
        id, path = string.match(line, "^/(%d+) %s*(%S*)")
    end

    if id then
        index = assert(tonumber(id))
        path = path
        original_entry = original_entries[index]
    else
        -- Parse as a new entry when an ID is not present
        index = nil
        path = vim.trim(line)
        original_entry = nil
    end

    -- Create an empty parsed entry, assume modified
    ---@type grapple.window.parsed_entry
    local entry = {
        ---@type grapple.tag_content.data
        data = {
            path = nil,
            name = nil,
            cursor = nil,
        },
        line = line,
        modified = true,
        index = index,
    }

    -- Don't parse an empty path or line
    if path == "" then
        return entry
    end

    -- We shouldn't try to join with the scope path if:
    -- 1. The path starts with "~", "./", or "../"
    -- 2. The path is absolute or a URI
    if Path.is_joinable(path) then
        path = Path.join(self.scope.path, path)
    end

    path = Path.fs_absolute(path)

    if original_entry and original_entry.data.path == path then
        ---@type grapple.window.parsed_entry
        ---@diagnostic disable-next-line: assign-type-mismatch
        entry = vim.deepcopy(original_entries[index])
        entry.modified = false

        return entry
    end

    entry.data.path = path

    return entry
end

---@class grapple.tag.content.change
---@field action "insert" | "move" | "remove"
---@field opts grapple.options

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
        ---@type grapple.tag_content.data
        local data

        if not entry.modified then
            data = original[entry.index].data
        else
            data = entry.data
        end

        ---@type grapple.tag.content.change
        local change = {
            action = "insert",
            opts = {
                path = data.path,
                name = data.name,
                cursor = data.cursor,
                index = i,
            },
        }

        table.insert(changes, change)
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
