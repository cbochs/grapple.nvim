local Path = require("grapple.path")
local Util = require("grapple.util")

---@class grapple.tag_content
---@field scope grapple.resolved_scope
---@field style_fn grapple.style_fn
---@field hook_fn grapple.hook_fn
---@field title_fn grapple.title_fn
---@field current_selection string | nil path of the current buffer
local TagContent = {}
TagContent.__index = TagContent

---@param scope grapple.resolved_scope
---@param style_fn grapple.style_fn
---@param hook_fn? grapple.hook_fn
---@param title_fn? grapple.title_fn
---@return grapple.tag_content
function TagContent:new(scope, style_fn, hook_fn, title_fn)
    return setmetatable({
        scope = scope,
        style_fn = style_fn,
        hook_fn = hook_fn,
        title_fn = title_fn,
        current_selection = nil,
    }, self)
end

---@return boolean
function TagContent:modifiable()
    return true
end

---Return the first editable cursor column for a line (0-indexed)
---@param line string
---@return integer min_col
function TagContent:minimum_column(line)
    local id = string.match(line, "^/(%d+)")
    if not id then
        return 0
    end

    -- Assume: editable content is always at the end of the line
    -- Assume: name can be part of the line if "name_pos" is set to "start"
    -- base:           2 splits: (id, path)
    -- w/ name:        3 splits: (id, name, path)
    -- w/ icon:        3 splits: (id, icon, path)
    -- w/ icon + name: 4 splits: (id, icon, name, path)
    local split = vim.split(line, "%s+")
    if #split <= 1 then
        return 0
    else
        local _, e = string.find(line, split[#split - 1])
        return e + 1
    end
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

    local base_lookup = Util.reduce(tags, function(lookup, tag)
        local base = Path.base(tag.path)
        lookup[base] = (lookup[base] or 0) + 1
        return lookup
    end, {})

    ---@type grapple.window.entity[]
    local entities = {}

    for _, tag in ipairs(tags) do
        ---@class grapple.tag_content.entity
        local entity = {
            tag = tag,
            current = tag.path == self.current_selection,
            base_unique = base_lookup[Path.base(tag.path)] == 1,
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
        -- stylua: ignore
        error(
            'The plugin "nvim-tree/nvim-web-devicons" is required for icons in Grapple.nvim. ' ..
            'To disable icons, change "icons" to false in the settings.'
        )
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

    -- Generate the display path
    local stylized = self.style_fn(entity, self)

    local icon, icon_group
    if app.settings.icons then
        icon, icon_group = get_icon(tag.path)
    end

    -- In compliance with "grapple" syntax
    local line_items = vim.tbl_filter(Util.not_nil, {
        id,
        icon,

        -- Neovim does not support defining extmarks that "push" some text
        -- instead of just "overlay". Render the name ahead of the displayed
        -- path instead of as an extmark when the user wants to show it at the
        -- start of the line
        app.settings.name_pos == "start" and tag.name or nil,

        stylized.display,
    })

    local line = table.concat(line_items, " ")
    local min_col = assert(string.find(line, Util.escape(stylized.display))) - 1

    -- Define line highlights for display and extmarks
    ---@type grapple.vim.highlight[]
    local highlights = {}

    local sign_highlight
    if not app.settings.status then
        -- Do not set highlight
    elseif entity.current then
        sign_highlight = "GrappleCurrent"
    elseif not Path.exists(tag.path) then
        sign_highlight = "GrappleNoExist"
    end

    ---@type grapple.vim.highlight | nil
    local icon_highlight
    if icon and icon_group then
        local col_start, col_end = assert(string.find(line, icon))
        icon_highlight = {
            hl_group = icon_group,
            line = index - 1,
            col_start = col_start - 1,
            col_end = col_end,
        }
    end

    ---@type grapple.vim.highlight | nil
    local name_highlight
    if app.settings.name_pos == "start" and tag.name then
        local col_start, col_end = assert(string.find(line, Util.escape(tag.name)))
        name_highlight = {
            hl_group = "GrappleName",
            line = index - 1,
            col_start = col_start - 1,
            col_end = col_end,
        }
    end

    highlights = vim.tbl_filter(Util.not_nil, {
        icon_highlight,
        name_highlight,
    })

    -- Define line extmarks
    ---@type grapple.vim.extmark[]
    local extmarks = {}

    ---@type grapple.vim.mark
    local sign_mark
    local quick_select = app.settings:quick_select()[index]
    if quick_select then
        sign_mark = {
            sign_text = string.format("%s", quick_select),
            sign_hl_group = sign_highlight,
        }
    end

    ---@type grapple.vim.mark
    local name_mark
    if app.settings.name_pos == "end" and tag.name then
        name_mark = {
            virt_text = { { tag.name, "GrappleName" } },
            virt_text_pos = "eol",
        }
    end

    extmarks = vim.tbl_filter(Util.not_nil, {
        sign_mark,
        unpack(stylized.marks),
        name_mark,
    })

    extmarks = vim.tbl_map(function(mark)
        return {
            line = index - 1,
            col = 0,
            opts = mark,
        }
    end, extmarks)

    ---@type grapple.window.entry
    local entry = {
        ---@class grapple.tag_content.data
        data = {
            display = stylized.display,
            path = tag.path,
            name = tag.name,
            cursor = tag.cursor,
        },

        line = line,
        index = index,
        min_col = min_col,

        ---@type grapple.vim.highlight[]
        highlights = highlights,

        ---@type grapple.vim.extmark[]
        extmarks = extmarks,
    }

    return entry
end

---@param line string
---@param original_entries grapple.window.entry[]
---@return grapple.window.parsed_entry
function TagContent:parse_line(line, original_entries)
    local id = string.match(line, "^/(%d+)")

    local index, display
    if id then
        index = assert(tonumber(id))
    else
        -- Parse as a new entry when an ID is not present
        index = nil
    end

    -- Minimum column returns the 0-indexed cursor column, convert to
    -- 1-indexed before using it
    local min_col = self:minimum_column(line) + 1
    display = vim.trim(string.sub(line, min_col))

    -- Create an empty parsed entry, assume modified
    ---@type grapple.window.parsed_entry
    local entry = {
        ---@type grapple.tag_content.data
        data = {
            display = display,
            path = nil,
            name = nil,
            cursor = nil,
        },
        line = line,
        modified = true,
        index = index,
    }

    -- Don't parse an empty path or line
    if display == "" then
        return entry
    end

    -- TODO: parsing probably shouldn't need access to the original entries.
    -- I do think it might be valuable to provide the line and extmarks linewise
    -- extmarks, but likely this logic to get the original entry should be
    -- pushed to the "diff" function
    if original_entries[index] then
        ---@type grapple.tag_content.data
        local data = original_entries[index].data

        if data.display == display then
            ---@type grapple.window.parsed_entry
            ---@diagnostic disable-next-line: assign-type-mismatch
            entry = vim.deepcopy(original_entries[index])
            entry.modified = false

            return entry
        else
            -- Keep the name associated with the original entry
            entry.data.name = data.name
        end
    end

    local path = display

    -- The display path has been modified. Only join if it is not explicitly
    -- relative to another known directory (i.e. starts with "./" or "~")
    if Path.is_joinable(path) then
        path = Path.join(self.scope.path, path)
    end

    -- Parse as a new entry when the display text has been modified
    entry.data.path = Path.fs_absolute(path)

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
