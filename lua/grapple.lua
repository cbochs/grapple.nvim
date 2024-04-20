local Grapple = {}

---@param err? string
---@return string? error
local function notify_err(err)
    if err then
        vim.notify(err, vim.log.levels.ERROR)
    end
    return err
end

---@return grapple.app
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
    return Grapple.app():exists(opts)
end

---Return the name or index of a tag. Used for statusline components
---@param opts? grapple.options
---@return string | integer | nil
function Grapple.name_or_index(opts)
    return Grapple.app():name_or_index(opts)
end

---Return the tags for a given scope (name) or loaded scope (id). Used for
---integrations
---@param opts? { scope?: string, scope_id?: string }
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

---Unload or reset tags for a given (scope) name or loaded scope (id)
---@param opts? { scope?: string, scope_id?: string, reset?: boolean, notify?: boolean }
---@return string? error
function Grapple.unload(opts)
    opts = vim.tbl_deep_extend("keep", opts or {}, { notify = true })

    local scope, err = Grapple.app():unload_scope({
        scope = opts.scope,
        scope_id = opts.scope_id,
        reset = opts.reset,
    })

    if opts.notify then
        ---@cast scope grapple.resolved_scope
        -- stylua: ignore
        local message = err and err
            or opts.reset and string.format("Scope reset: %s", scope.name or scope.id)
            or string.format("Scope unloaded: %s", scope.name or scope.id)

        vim.notify(message, err and vim.log.levels.ERROR or vim.log.levels.INFO)
    end

    if err then
        return err
    end
end

---Reset tags for a given (scope) name or loaded scope (id)
---@param opts? { scope?: string, scope_id?: string, notify?: boolean }
---@return string? error
function Grapple.reset(opts)
    ---@diagnostic disable-next-line: param-type-mismatch
    Grapple.unload(vim.tbl_deep_extend("force", opts or {}, { reset = true }))
end

---Convenience function to toggle content in a floating window
---@param open_fn function
---@param opts any
---@return string? error
local function toggle(open_fn, opts)
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = 0 })
    if filetype == "grapple" then
        return vim.cmd.close()
    end

    return open_fn(opts)
end

---Open a floating window populated with all tags for a given (scope) name
---or loaded scope (id). By default, uses the current scope
---@param opts? { scope?: string, scope_id?: string, style?: string }
---@return string? error
function Grapple.open_tags(opts)
    return notify_err(Grapple.app():open_tags(opts))
end

---Toggle a floating window populated with all tags for a given (scope) name
---or loaded scope (id). By default, uses the current scope
---@param opts? { scope?: string, scope_id?: string }
---@return string? error
function Grapple.toggle_tags(opts)
    notify_err(toggle(Grapple.open_tags, opts))
end

---Open a floating window populated with all defined scopes
---@param opts? { all: boolean }
function Grapple.open_scopes(opts)
    notify_err(Grapple.app():open_scopes(opts))
end

---Toggle a floating window populated with all defined scopes
function Grapple.toggle_scopes()
    notify_err(toggle(Grapple.open_scopes))
end

---Open a floating window populated with all loaded scopes
---@param opts? { all: boolean }
function Grapple.open_loaded(opts)
    notify_err(Grapple.app():open_loaded(opts))
end

---Toggle a floating window populated with all loaded scopes
---@param opts? { all: boolean }
function Grapple.toggle_loaded(opts)
    notify_err(toggle(Grapple.open_loaded, opts))
end

---Prune save files based on their last modified time
---@param opts? { limit?: integer | string, notify?: boolean }
---@return string[] | nil, string? error
function Grapple.prune(opts)
    local Util = require("grapple.util")

    opts = opts or {}

    local pruned_ids, err = Grapple.app():prune({ limit = opts.limit })

    if err then
        return vim.notify(err --[[ @as string ]], vim.log.levels.ERROR)
    end

    ---@cast pruned_ids string[]
    if #pruned_ids == 0 then
        vim.notify("Pruned 0 save files", vim.log.levels.INFO)
    elseif #pruned_ids == 1 then
        vim.notify(string.format("Pruned 1 save file: %s", pruned_ids[1]), vim.log.levels.INFO)
    else
        local output_tbl = vim.tbl_map(Util.with_prefix("  "), pruned_ids)
        local output = table.concat(output_tbl, "\n")
        vim.notify(string.format("Pruned %d save files\n%s", #pruned_ids, output), vim.log.levels.INFO)
    end

    return pruned_ids, err
end

---Open the quickfix window populated with paths from a given (scope) name
---or loaded scope (id). By default, uses the current scope
---@param opts? { scope?: string, scope_id?: string }
function Grapple.quickfix(opts)
    local Path = require("grapple.path")
    local app = Grapple.app()

    opts = opts or {}

    local tags, err = app:tags({ scope = opts.scope, scope_id = opts.scope_id })
    if err or not tags then
        return err
    end

    local quickfix_list = {}
    local cwd = assert(vim.loop.cwd())

    for _, tag in ipairs(tags) do
        local cursor = tag.cursor or { 1, 0 }

        ---See :h vim.fn.setqflist
        ---@class grapple.vim.quickfix
        table.insert(quickfix_list, {
            filename = tag.path,
            lnum = cursor[1],
            col = cursor[2] + 1,
            text = Path.fs_relative(cwd, tag.path),
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
