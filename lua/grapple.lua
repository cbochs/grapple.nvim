local Grapple = {}

function Grapple.app()
    return require("grapple.app").get()
end

---@param opts? grapple.settings
function Grapple.setup(opts)
    local err = Grapple.app():update(opts)
    if err then
        return vim.notify(err, vim.log.levels.ERROR)
    end
end

---Create a new tag or update an existing tag on a path, URI, or buffer
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.tag(opts)
    Grapple.app():tag(opts)
end

---Delete a tag on a path, URI, or buffer
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.untag(opts)
    Grapple.app():untag(opts)
end

---Toggle a tag on a path, URI, or buffer. Lookup is done by index, name, path, or buffer
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.toggle(opts)
    Grapple.app():toggle(opts)
end

---Select a tag by index, name, path, or buffer
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.select(opts)
    Grapple.app():select(opts)
end

-- Cycle through and select the next or previous available tag for a given scope.
---By default, uses the current scope
---@param direction "next" | "prev" | "previous" | "forward" | "backward"
---@param opts? grapple.options
function Grapple.cycle_tags(direction, opts)
    Grapple.app():cycle_tags(direction, opts)
end

-- Cycle through and select the next or previous available tag for a given scope.
---By default, uses the current scope
---@deprecated Soft-deprecated in favour of Grapple.cycle_tags
---@param direction "forward" | "backward"
---@param opts? grapple.options
function Grapple.cycle(direction, opts)
    Grapple.cycle_tags(direction, opts)
end

---Select the next available tag for a given scope
---By default, uses the current scope
---@deprecated Soft-deprecated in favour of Grapple.cycle_tags
---@param opts? grapple.options
function Grapple.cycle_forward(opts)
    Grapple.cycle_tags("next", opts)
end

---Select the previous available tag for a given scope
---By default, uses the current scope
---@deprecated Soft-deprecated in favour of Grapple.cycle_tags
---@param opts? grapple.options
function Grapple.cycle_backward(opts)
    Grapple.cycle_tags("prev", opts)
end

---Search for a tag in a given scope
---@param opts? grapple.options
---@return grapple.tag | nil, string? error
function Grapple.find(opts)
    return Grapple.app():find(opts)
end

---Return if a tag exists. Used for statusline components
---@param opts? grapple.options
---@return boolean
function Grapple.exists(opts)
    return Grapple.app():exists(opts)
end

---Return the name or index of a tag. Used for statusline components
---@param opts? grapple.options
---@return string | integer | nil
function Grapple.name_or_index(opts)
    return Grapple.app():name_or_index(opts)
end

---Return the tags for a given scope. Used for integrations
---@param opts? { scope?: string }
---@return grapple.tag[] | nil, string? error
function Grapple.tags(opts)
    return Grapple.app():tags(opts)
end

---Create a user-defined scope
---@param definition grapple.scope_definition
---@return string? error
function Grapple.define_scope(definition)
    return Grapple.app():define_scope(definition)
end

---Delete a user-defined or default scope
---@param scope string
---@return string? error
function Grapple.delete_scope(scope)
    return Grapple.app():delete_scope(scope)
end

---Change the currently selected scope
---@param scope string
function Grapple.use_scope(scope)
    return Grapple.app():use_scope(scope)
end

---Unload tags for a give (scope) name or loaded scope (id)
---@param opts? { scope?: string, id?: string, notify?: boolean }
---@return string? error
function Grapple.unload(opts)
    return Grapple.app():unload(opts)
end

---Reset tags for a given (scope) name or loaded scope (id)
---@param opts? { scope?: string, id?: string, notify?: boolean }
---@return string? error
function Grapple.reset(opts)
    return Grapple.app():reset(opts)
end

---Convenience function to toggle content in a floating window
---@param open_fn function
---@param opts any
local function toggle(open_fn, opts)
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = 0 })
    if filetype == "grapple" then
        vim.cmd.close()
    else
        open_fn(opts)
    end
end

---Open a floating window populated with all tags for a given (scope) name
---or loaded scope (id). By default, uses the current scope
---@param opts? { scope?: string, id?: string, style?: string }
function Grapple.open_tags(opts)
    Grapple.app():open_tags(opts)
end

---Toggle a floating window populated with all tags for a given (scope) name
---or loaded scope (id). By default, uses the current scope
---@param opts? { scope?: string, id?: string }
function Grapple.toggle_tags(opts)
    toggle(Grapple.open_tags, opts)
end

---Open a floating window populated with all defined scopes
---@param opts? { all: boolean }
function Grapple.open_scopes(opts)
    Grapple.app():open_scopes(opts)
end

---Toggle a floating window populated with all defined scopes
function Grapple.toggle_scopes()
    toggle(Grapple.open_scopes)
end

---Open a floating window populated with all loaded scopes
---@param opts? { all: boolean }
function Grapple.open_loaded(opts)
    Grapple.app():open_loaded(opts)
end

---Toggle a floating window populated with all loaded scopes
---@param opts? { all: boolean }
function Grapple.toggle_loaded(opts)
    toggle(Grapple.open_loaded, opts)
end

---Prune save files based on their last modified time
---@param opts? { limit?: integer | string, notify?: boolean }
---@return string[] | nil, string? error
function Grapple.prune(opts)
    Grapple.app():prune(opts)
end

---Open the quickfix window populated with paths from a given (scope) name
---or loaded scope (id). By default, uses the current scope
---@param opts? { scope?: string, id?: string }
function Grapple.quickfix(opts)
    local App = require("grapple.app")
    local Path = require("grapple.path")

    local app = App.get()

    opts = opts or {}

    local scope, err
    if opts.id then
        scope, err = app.scope_manager:lookup(opts.id)
    else
        scope, err = app.scope_manager:get_resolved(opts.scope or app.settings.scope)
    end

    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    ---@diagnostic disable-next-line: redefined-local
    local tags, err = scope:tags()
    if not tags then
        return err
    end

    local quickfix_list = {}

    for _, tag in ipairs(tags) do
        ---See :h vim.fn.setqflist
        ---@class grapple.vim.quickfix
        table.insert(quickfix_list, {
            filename = tag.path,
            lnum = tag.cursor[1],
            col = tag.cursor[2] + 1,
            text = Path.fs_relative(scope.path, tag.path),
        })
    end

    if #quickfix_list > 0 then
        vim.fn.setqflist(quickfix_list, "r")
        vim.cmd.copen()
    end
end

---Return a formatted string to be displayed on the statusline
---@param opts grapple.statusline.options
---@return string | nil
function Grapple.statusline(opts)
    local App = require("grapple.app")
    local app = App.get()

    opts = vim.tbl_deep_extend("keep", opts or {}, app.settings.statusline)

    local tags, err = Grapple.tags()
    if not tags then
        return err
    end

    local current = Grapple.find({ buffer = 0 })

    local quick_select = app.settings:quick_select()
    local output = {}

    for i, tag in ipairs(tags) do
        -- stylua: ignore
        local tag_str = tag.name and tag.name
            or quick_select[i] and quick_select[i]
            or i

        local tag_fmt = opts.inactive
        if current and current.path == tag.path then
            tag_fmt = opts.active
        end

        table.insert(output, string.format(tag_fmt, tag_str))
    end

    local statusline = table.concat(output)
    if opts.include_icon then
        statusline = string.format("%s %s", opts.icon, statusline)
    end

    return statusline
end

return Grapple
