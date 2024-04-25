local Grapple = {}

---@param err? string
---@return string? err
local function notify_err(err)
    if err and not vim.env.CI then
        vim.notify(err, vim.log.levels.ERROR)
    end
    return err
end

function Grapple.app()
    return require("grapple.app").get()
end

---@param opts? grapple.settings
---@return string? error
function Grapple.setup(opts)
    return notify_err(Grapple.app():update(opts))
end

---Create a new tag or update an existing tag on a path, URI, or buffer
---By default, uses the current scope
---@param opts? grapple.options
---@return string? error
function Grapple.tag(opts)
    return notify_err(Grapple.app():tag(opts))
end

---Delete a tag on a path, URI, or buffer
---By default, uses the current scope
---@param opts? grapple.options
---@return string? error
function Grapple.untag(opts)
    return notify_err(Grapple.app():untag(opts))
end

---Toggle a tag on a path, URI, or buffer. Lookup is done by index, name, path, or buffer
---By default, uses the current scope
---@param opts? grapple.options
---@return string? error
function Grapple.toggle(opts)
    return notify_err(Grapple.app():toggle(opts))
end

---Select a tag by index, name, path, or buffer
---By default, uses the current scope
---@param opts? grapple.options
---@return string? error
function Grapple.select(opts)
    return notify_err(Grapple.app():select(opts))
end

-- Cycle through and select the next or previous available tag for a given scope.
---By default, uses the current scope
---@param direction "next" | "prev" | "previous" | "forward" | "backward"
---@param opts? grapple.options
---@return string? error
function Grapple.cycle_tags(direction, opts)
    return notify_err(Grapple.app():cycle_tags(direction, opts))
end

-- Cycle through and select the next or previous available tag for a given scope.
---By default, uses the current scope
---@deprecated Soft-deprecated in favour of Grapple.cycle_tags
---@param direction "forward" | "backward"
---@param opts? grapple.options
---@return string? error
function Grapple.cycle(direction, opts)
    return Grapple.cycle_tags(direction, opts)
end

---Select the next available tag for a given scope
---By default, uses the current scope
---@deprecated Soft-deprecated in favour of Grapple.cycle_tags
---@param opts? grapple.options
---@return string? error
function Grapple.cycle_forward(opts)
    return Grapple.cycle_tags("next", opts)
end

---Select the previous available tag for a given scope
---By default, uses the current scope
---@deprecated Soft-deprecated in favour of Grapple.cycle_tags
---@param opts? grapple.options
---@return string? error
function Grapple.cycle_backward(opts)
    return Grapple.cycle_tags("prev", opts)
end

---@param opts? grapple.options
---@return string? error
function Grapple.touch(opts)
    return Grapple.app():touch(opts)
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
    return Grapple.find(opts) ~= nil
end

---Return the name or index of a tag. Used for statusline components
---@param opts? grapple.options
---@return string | integer | nil
function Grapple.name_or_index(opts)
    return Grapple.app():name_or_index(opts)
end

---Return the tags for a given scope. Used for integrations
---@param opts? { scope?: string, id?: string }
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
---@param opts? { notify?: boolean }
---@return string? error
function Grapple.use_scope(scope, opts)
    opts = vim.tbl_deep_extend("keep", opts or {}, { notify = true })

    local err = Grapple.app():use_scope(scope)
    if err then
        vim.notify(err, vim.log.levels.ERROR)
    elseif opts.notify then
        vim.notify(string.format("Scope changed: %s", scope))
    end

    if err then
        return err
    end
end

---Unload tags for a give (scope) name or loaded scope (id)
---@param opts? { scope?: string, id?: string, notify?: boolean }
---@return string? error
function Grapple.unload(opts)
    opts = opts or {}

    local err = Grapple.app():unload_scope({ scope = opts.scope, id = opts.id })
    if err then
        if opts.notify then
            vim.notify(err, vim.log.levels.ERROR)
        end
        return err
    end

    if opts.notify then
        vim.notify(string.format("Scope unloaded: %s", opts.scope or opts.id), vim.log.levels.INFO)
    end
end

---Reset tags for a given (scope) name or loaded scope (id)
---By default, uses the current scope
---@param opts? { scope?: string, id?: string, notify?: boolean }
---@return string? error
function Grapple.reset(opts)
    opts = opts or {}

    local err = Grapple.app():reset_scope({ scope = opts.scope, id = opts.id })
    if err then
        if opts.notify then
            vim.notify(err, vim.log.levels.ERROR)
        end
        return err
    end

    if opts.notify then
        vim.notify(string.format("Scope reset: %s", opts.scope or opts.id), vim.log.levels.INFO)
    end
end

---@deprecated
---@param scope? string
function Grapple.clear_cache(scope)
    Grapple.app().scope_manager.cache:invalidate(scope or Grapple.app().settings.scope)
end

---Convenience function to toggle content in a floating window
---@param open_fn function
---@param opts any
---@return string? error
local function toggle(open_fn, opts)
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = 0 })
    if filetype == "grapple" then
        vim.cmd.close()
    else
        return open_fn(opts)
    end
end

---Open a floating window populated with all tags for a given (scope) name
---or loaded scope (id). By default, uses the current scope
---@param opts? { scope?: string, id?: string, style?: string }
---@return string? error
function Grapple.open_tags(opts)
    return notify_err(Grapple.app():open_tags(opts))
end

---Toggle a floating window populated with all tags for a given (scope) name
---or loaded scope (id). By default, uses the current scope
---@param opts? { scope?: string, id?: string }
---@return string? error
function Grapple.toggle_tags(opts)
    return toggle(Grapple.open_tags, opts)
end

---Open a floating window populated with all defined scopes
---@param opts? { all: boolean }
function Grapple.open_scopes(opts)
    return notify_err(Grapple.app():open_scopes(opts))
end

---Toggle a floating window populated with all defined scopes
function Grapple.toggle_scopes()
    toggle(Grapple.open_scopes)
end

---Open a floating window populated with all loaded scopes
---@param opts? { all: boolean }
function Grapple.open_loaded(opts)
    return notify_err(Grapple.app():open_loaded(opts))
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
    local Util = require("grapple.util")
    local app = Grapple.app()

    opts = opts or {}

    local pruned_ids, err = app.tag_manager:prune(opts.limit or app.settings.prune)
    if not pruned_ids then
        if opts.notify then
            ---@diagnostic disable-next-line: param-type-mismatch
            vim.notify(err, vim.log.levels.ERROR)
        end
        return nil, err
    end

    if opts.notify then
        if #pruned_ids == 0 then
            vim.notify("Pruned 0 save files", vim.log.levels.INFO)
        elseif #pruned_ids == 1 then
            vim.notify(string.format("Pruned %d save file: %s", #pruned_ids, pruned_ids[1]), vim.log.levels.INFO)
        else
            vim.print(pruned_ids)
            local output_tbl = vim.tbl_map(Util.with_prefix("  "), pruned_ids)
            local output = table.concat(output_tbl, "\n")
            vim.notify(string.format("Pruned %d save files\n%s", #pruned_ids, output), vim.log.levels.INFO)
        end
    end

    return pruned_ids, nil
end

---Open the quickfix window populated with paths from a given (scope) name
---or loaded scope (id). By default, uses the current scope
---@param opts? { scope?: string, id?: string }
function Grapple.quickfix(opts)
    local Path = require("grapple.path")
    local app = Grapple.app()

    opts = opts or {}

    ---@diagnostic disable-next-line: redefined-local
    local tags, err = app:tags({ scope = opts.scope, id = opts.id })
    if not tags then
        return err
    end

    local quickfix_list = {}
    local cwd = assert(vim.loop.cwd())

    for _, tag in ipairs(tags) do
        ---See :h vim.fn.setqflist
        ---@class grapple.vim.quickfix
        table.insert(quickfix_list, {
            filename = tag.path,
            lnum = tag.cursor[1],
            col = tag.cursor[2] + 1,
            text = Path.fs_relative(cwd, tag.path),
        })
    end

    if #quickfix_list > 0 then
        vim.fn.setqflist(quickfix_list, "r")
        vim.cmd.copen()
    end
end

---Return a formatted string to be displayed on the statusline
---@param opts? grapple.statusline.options
---@return string | nil
function Grapple.statusline(opts)
    local app = Grapple.app()

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
