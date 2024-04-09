local Grapple = {}

---@param opts? grapple.settings
function Grapple.setup(opts)
    local app = require("grapple.app").get()

    local err = app:update(opts)
    if err then
        return vim.notify(err, vim.log.levels.ERROR)
    end
end

---@class grapple.options
---@field buffer? integer
---@field path? string
---@field name? string
---@field index? integer
---@field cursor? integer[]
---@field scope? string
---@field command? fun(path: string)

---Extract a valid path from the provided path or buffer options.
---@param opts grapple.options
---@return string | nil path, string? error
local function extract_path(opts)
    local App = require("grapple.app")
    local app = App.get()

    -- Special case: get the path under the cursor
    if opts.path and opts.path == "<cfile>" then
        return vim.fn.expand("<cfile>")
    end

    if opts.path then
        return opts.path
    end

    local buffer = opts.buffer or 0

    if not vim.api.nvim_buf_is_valid(buffer) then
        return nil, string.format("invalid buffer: %s", buffer)
    end

    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buffer })
    if vim.tbl_contains(app.settings.exclusions.buftype, buftype) then
        return nil, string.format("invalid buftype for buffer %s: %s", buffer, buftype)
    end

    local filetype = vim.api.nvim_get_option_value("filetype", { buf = buffer })
    if vim.tbl_contains(app.settings.exclusions.filetype, filetype) then
        return nil, string.format("invalid filetype for buffer %s: %s", buffer, filetype)
    end

    local bufname = vim.api.nvim_buf_get_name(buffer)
    if vim.tbl_contains(app.settings.exclusions.name, bufname) then
        return nil, string.format('invalid name for buffer %s: "%s"', buffer, bufname)
    end

    return vim.api.nvim_buf_get_name(buffer), nil
end

---Create a new tag or update an existing tag on a path, URI, or buffer
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.tag(opts)
    local App = require("grapple.app")

    opts = opts or {}

    local app = App.get()
    app:enter_with_save(opts.scope, function(container)
        local path, err = extract_path(opts)
        if not path then
            return err
        end
        opts.path = path

        return container:insert(opts)
    end)
end

---Delete a tag on a path, URI, or buffer
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.untag(opts)
    local App = require("grapple.app")

    opts = opts or {}

    local app = App.get()
    app:enter_with_save(opts.scope, function(container)
        local path, err = extract_path(opts)
        if not path then
            return err
        end
        opts.path = path

        return container:remove(opts)
    end)
end

---Toggle a tag on a path, URI, or buffer. Lookup is done by index, name, path, or buffer
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.toggle(opts)
    local App = require("grapple.app")

    opts = opts or {}

    local app = App.get()
    app:enter_with_save(opts.scope, function(container)
        local path, err = extract_path(opts)
        if not path then
            return err
        end
        opts.path = path

        if container:has(opts) then
            return container:remove(opts)
        else
            return container:insert(opts)
        end
    end)
end

---Select a tag by index, name, path, or buffer
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.select(opts)
    local App = require("grapple.app")

    opts = opts or {}

    local app = App.get()
    app:enter_without_save(opts.scope, function(container)
        local path, _ = extract_path(opts)
        opts.path = path

        ---@diagnostic disable-next-line: redefined-local
        local index, err = container:find(opts)
        if not index then
            return err
        end

        local tag = assert(container:get({ index = index }))

        tag:select(opts.command)
    end)
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

---@param current_index? integer
---@param direction "next" | "prev"
---@param length integer
---@return integer
local function next_index(current_index, direction, length)
    -- Fancy maths to get the next index for a given direction
    -- 1. Change to 0-based indexing
    -- 2. Perform index % container length, being careful of negative values
    -- 3. Change back to 1-based indexing
    -- stylua: ignore
    current_index = (
        current_index
        or direction == "next" and length
        or direction == "prev" and 1
    ) - 1

    local next_inc = direction == "next" and 1 or -1
    local next_idx = math.fmod(current_index + next_inc + length, length) + 1

    return next_idx
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

-- Cycle through and select the next or previous available tag for a given scope.
---By default, uses the current scope
---@deprecated Soft-deprecated in favour of Grapple.cycle_tags
---@param direction "forward" | "backward"
---@param opts? grapple.options
function Grapple.cycle(direction, opts)
    Grapple.cycle_tags(direction, opts)
end

-- Cycle through and select the next or previous available tag for a given scope.
---By default, uses the current scope
---@param direction "next" | "prev" | "previous" | "forward" | "backward"
---@param opts? grapple.options
function Grapple.cycle_tags(direction, opts)
    local App = require("grapple.app")
    local app = App.get()

    opts = opts or {}

    -- stylua: ignore
    direction = direction == "forward" and "next"
        or direction == "backward" and "prev"
        or direction == "previous" and "prev"
        or direction

    ---@cast direction "next" | "prev"
    if not vim.tbl_contains({ "next", "prev" }, direction) then
        return vim.notify(string.format("invalid direction: %s", direction), vim.log.levels.ERROR)
    end

    app:enter_without_save(opts.scope, function(container)
        if container:is_empty() then
            return
        end

        local path, _ = extract_path(opts)
        opts.path = path

        local index = next_index(container:find(opts), direction, container:len())

        ---@diagnostic disable-next-line: redefined-local
        local tag, err = container:get({ index = index })
        if not tag then
            return err
        end

        ---@diagnostic disable-next-line: redefined-local
        local err = tag:select()
        if err then
            return err
        end
    end)
end

---Search for a tag in a given scope
---@param opts? grapple.options
---@return grapple.tag | nil, string? error
function Grapple.find(opts)
    local App = require("grapple.app")
    local app = App.get()

    opts = opts or {}

    ---@type grapple.tag | nil
    local tag

    local err = app:enter_without_save(opts.scope, function(container)
        local path, _ = extract_path(opts)
        opts.path = path

        local index, err = container:find(opts)
        if not index then
            return err
        end

        tag = assert(container:get({ index = index }))
    end, { notify = false })

    if err then
        return nil, err
    end

    return tag, nil
end

---Return if a tag exists. Used for statusline components
---@param opts? grapple.options
function Grapple.exists(opts)
    return Grapple.find(opts) ~= nil
end

---Return the name or index of a tag. Used for statusline components
---@param opts? grapple.options
---@return string | integer | nil
function Grapple.name_or_index(opts)
    local App = require("grapple.app")
    local app = App.get()

    opts = opts or {}

    ---@type string | integer | nil
    local name_or_index

    app:enter_without_save(opts.scope, function(container)
        local path, _ = extract_path(opts)
        opts.path = path

        local tag = container:get(opts)
        if tag then
            name_or_index = tag.name or assert(container:find(opts))
        end
    end)

    return name_or_index
end

---Return the tags for a given scope. Used for integrations
---@param opts? { scope?: string }
---@return grapple.tag[] | nil, string? error
function Grapple.tags(opts)
    local App = require("grapple.app")
    local app = App.get()

    opts = opts or {}

    local scope, err = app.scope_manager:get_resolved(opts.scope or app.settings.scope)
    if not scope then
        return nil, err
    end

    ---@diagnostic disable-next-line: redefined-local
    local tags, err = scope:tags()
    if not tags then
        return nil, err
    end

    return vim.deepcopy(tags), nil
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

---Unload tags for a give (scope) name or loaded scope (id)
---@param opts? { scope?: string, id?: string, notify?: boolean }
---@return string? error
function Grapple.unload(opts)
    local App = require("grapple.app")
    local app = App.get()

    opts = opts or {}

    local err = app:unload(opts)
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
    local App = require("grapple.app")
    local app = App.get()

    opts = opts or {}

    local err = app:reset(opts)
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

---Prune save files based on their last modified time
---@param opts? { limit?: integer | string, notify?: boolean }
---@return string[] | nil, string? error
function Grapple.prune(opts)
    local Util = require("grapple.util")
    local App = require("grapple.app")
    local app = App.get()

    opts = opts or {}

    local pruned_ids, err = app.tag_manager:prune(opts.limit or app.settings.prune)
    if not pruned_ids then
        if opts.notify then
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

---Create a user-defined scope
---@param definition grapple.scope_definition
---@return string? error
function Grapple.define_scope(definition)
    local App = require("grapple.app")
    local app = App.get()
    return app:define_scope(definition)
end

---Delete a user-defined or default scope
---@param scope string
---@return string? error
function Grapple.delete_scope(scope)
    local App = require("grapple.app")
    local app = App.get()
    return app:delete_scope(scope)
end

---Change the currently selected scope
---@param scope_name string
function Grapple.use_scope(scope_name)
    local App = require("grapple.app")
    local app = App.get()

    local scope, err = app.scope_manager:get(scope_name)
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    if scope.name ~= app.settings.scope then
        app.settings:update({ scope = scope.name })

        vim.api.nvim_exec_autocmds("User", {
            pattern = "GrappleScopeChanged",
            modeline = false,
        })

        vim.notify(string.format("Changing scope: %s", scope.name))
    end
end

---@param scope? string
function Grapple.clear_cache(scope)
    local App = require("grapple.app")
    local app = App.get()
    app.scope_manager.cache:invalidate(scope or app.settings.scope)
end

---Convenience function to open content in a new floating window
---@param content grapple.tag_content | grapple.scope_content | grapple.container_content
local function open(content)
    local App = require("grapple.app")
    local Window = require("grapple.window")

    local app = App:get()
    local window = Window:new(app.settings.win_opts)

    window:open()
    window:attach(content)

    local err = window:render()
    if err then
        vim.notify(err, vim.log.levels.ERROR)
    end
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

---Toggle a floating window populated with all tags for a given (scope) name
---or loaded scope (id). By default, uses the current scope
---@param opts? { scope?: string, id?: string }
function Grapple.toggle_tags(opts)
    toggle(Grapple.open_tags, opts)
end

---Open a floating window populated with all tags for a given (scope) name
---or loaded scope (id). By default, uses the current scope
---@param opts? { scope?: string, id?: string, style?: string }
function Grapple.open_tags(opts)
    local App = require("grapple.app")
    local TagContent = require("grapple.tag_content")

    opts = opts or {}

    local app = App.get()

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

    -- stylua: ignore
    local content = TagContent:new(
        scope,
        app.settings.tag_hook,
        app.settings.tag_title,
        app.settings.styles[opts.style or app.settings.style]
    )

    open(content)
end

---Toggle a floating window populated with all defined scopes
function Grapple.toggle_scopes()
    toggle(Grapple.open_scopes)
end

---Open a floating window populated with all defined scopes
---@param opts? { all: boolean }
function Grapple.open_scopes(opts)
    local ScopeContent = require("grapple.scope_content")
    local App = require("grapple.app")
    local app = App.get()

    local show_all = opts and opts.all or false
    local content = ScopeContent:new(app, app.settings.scope_hook, app.settings.scope_title, show_all)

    open(content)
end

---Toggle a floating window populated with all loaded scopes
---@param opts? { all: boolean }
function Grapple.toggle_loaded(opts)
    toggle(Grapple.open_loaded, opts)
end

---Open a floating window populated with all loaded scopes
---@param opts? { all: boolean }
function Grapple.open_loaded(opts)
    local ContainerContent = require("grapple.container_content")
    local App = require("grapple.app")
    local app = App.get()

    local show_all = opts and opts.all or false
    local content = ContainerContent:new(app, app.settings.loaded_hook, app.settings.loaded_title, show_all)

    open(content)
end

---Initialize Grapple. Sets up autocommands to watch tagged files and creates the
---"Grapple" user command. Called only once when plugin is loaded.
function Grapple.initialize()
    -- Create highlights for Grapple windows
    vim.cmd("highlight default GrappleBold gui=bold cterm=bold")
    vim.cmd("highlight default link GrappleHint Comment")
    vim.cmd("highlight default link GrappleName DiagnosticHint")
    vim.cmd("highlight default link GrappleNoExist DiagnosticError")

    vim.cmd("highlight default GrappleCurrent gui=bold cterm=bold")
    vim.cmd("highlight! link GrappleCurrent SpecialChar")

    -- Create autocommand to keep Grapple state up-to-date
    vim.api.nvim_create_augroup("Grapple", { clear = true })
    vim.api.nvim_create_autocmd({ "BufWinLeave", "QuitPre" }, {
        pattern = "?*", -- non-empty file
        group = "Grapple",
        callback = function(opts)
            local app = require("grapple.app").get()
            local buf_name = vim.api.nvim_buf_get_name(opts.buf)
            app.tag_manager:update_all({ path = buf_name })
        end,
    })

    -- Create top-level user command. Basically a wrapper around the lua API
    vim.api.nvim_create_user_command(
        "Grapple",

        ---@param opts grapple.vim.user_command
        function(opts)
            local action = opts.fargs[1] or "toggle"
            local args = {}
            local kwargs = {}

            for _, arg in ipairs({ unpack(opts.fargs, 2) }) do
                local key, value = string.match(arg, "^(.*)=(.*)$")

                if value == "" then
                    value = nil
                end

                if not key then
                    table.insert(args, tonumber(arg) or arg)
                else
                    kwargs[key] = tonumber(value) or value
                end
            end

            if not Grapple[action] then
                return vim.notify(string.format("invalid action: %s", action), vim.log.levels.WARN)
            end

            if #args > 0 and not vim.tbl_isempty(kwargs) then
                Grapple[action](unpack(args), kwargs)
            elseif #args > 0 and vim.tbl_isempty(kwargs) then
                Grapple[action](unpack(args))
            elseif #args == 0 and not vim.tbl_isempty(kwargs) then
                Grapple[action](kwargs)
            else
                Grapple[action]()
            end
        end,
        {
            desc = "Grapple",
            nargs = "*",
            complete = function(current, command, _)
                local Util = require("grapple.util")
                local App = require("grapple.app")
                local app = App.get()

                -- Keyword argument names permitted by Grapple
                -- "tag" kwargs refer to methods that accept all keyword arguments (i.e. toggle)
                -- "new" kwargs refer to methods that create a new tag (i.e. tag)
                -- "use" kwargs refer to methods that use an existing tag (i.e. select)
                -- "scope" kwargs refer to methods that operate on a scope (i.e. quickfix)
                -- "window" kwargs refer to methods that open a window (i.e. toggle_tags)
                local tag_kwargs = { "buffer", "path", "name", "index", "scope", "command" }
                local new_kwargs = Util.subtract(tag_kwargs, { "command" })
                local use_kwargs = Util.subtract(tag_kwargs, { "command" })
                local scope_kwargs = { "scope", "id" }
                local window_kwargs = { "style", unpack(scope_kwargs) }

                -- stylua: ignore
                -- Lookup table of API functions and their available arguments
                local subcommand_lookup = {
                    clear_cache    = { args = { "scope" },     kwargs = {} },
                    cycle_tags     = { args = { "direction" }, kwargs = use_kwargs },
                    open_loaded    = { args = {},              kwargs = { "all" } },
                    open_scopes    = { args = {},              kwargs = {} },
                    open_tags      = { args = {},              kwargs = window_kwargs },
                    prune          = { args = {},              kwargs = { "limit" } },
                    quickfix       = { args = {},              kwargs = scope_kwargs },
                    reset          = { args = {},              kwargs = scope_kwargs },
                    select         = { args = {},              kwargs = use_kwargs },
                    tag            = { args = {},              kwargs = new_kwargs },
                    toggle         = { args = {},              kwargs = tag_kwargs },
                    toggle_loaded  = { args = {},              kwargs = { "all" } },
                    toggle_scopes  = { args = {},              kwargs = { "all" } },
                    toggle_tags    = { args = {},              kwargs = window_kwargs },
                    unload         = { args = {},              kwargs = scope_kwargs },
                    untag          = { args = {},              kwargs = use_kwargs },
                    use_scope      = { args = { "scope" },     kwargs = {} },
                }

                -- Lookup table of arguments and their known values
                local argument_lookup = {
                    all = { "true", "false" },
                    direction = { "next", "prev" },
                    scope = Util.sort(vim.tbl_keys(app.scope_manager.scopes), Util.as_lower),
                    style = Util.sort(vim.tbl_keys(app.settings.styles), Util.as_lower),
                }

                -- API methods which are not actionable
                local excluded_subcmds = {
                    -- Deprecated
                    "cycle",
                    "cycle_backward",
                    "cycle_forward",

                    "define_scope",
                    "delete_scope",
                    "exists",
                    "find",
                    "initialize",
                    "key",
                    "name_or_index",
                    "setup",
                    "statusline",
                    "tags",
                }

                -- Grab all actionable subcommands made available by Grapple
                local subcmds = vim.tbl_keys(Grapple)
                subcmds = Util.subtract(subcmds, excluded_subcmds)
                table.sort(subcmds, Util.as_lower)

                local check = vim.tbl_keys(subcommand_lookup)
                check = Util.subtract(check, excluded_subcmds)
                table.sort(check, Util.as_lower)

                -- Ensure we aren't missing in the lookup table above
                if not Util.same(subcmds, check) then
                    local missing = Util.subtract(subcmds, check)
                    error(string.format("missing lookup for subcommands: %s", table.concat(missing, ", ")))
                end

                -- Time to start processing the command
                local input = vim.split(command, "%s+")
                local input_subcmd = input[2]
                local input_rem = { unpack(input, 3) }

                -- "Grapple |"
                -- "Grapple sub|"

                if #input == 2 then
                    -- stylua: ignore
                    return current == ""
                        and subcmds
                        or vim.tbl_filter(Util.startswith(current), subcmds)
                end

                local completion = subcommand_lookup[input_subcmd]
                if not completion then
                    return
                end

                local input_args = { unpack(input_rem, 1, #completion.args) }
                local input_kwargs = { unpack(input_rem, #completion.args + 1) }

                -- "Grapple subcmd |"
                -- "Grapple subcmd ar|"

                if #input_kwargs == 0 then
                    local arg_name = completion.args[#input_args]
                    local arg_values = argument_lookup[arg_name] or {}

                    -- stylua: ignore
                    return current == ""
                        and arg_values
                        or vim.tbl_filter(Util.startswith(current), arg_values)
                end

                -- "Grapple subcmd arg |"
                -- "Grapple subcmd arg k|"

                local key, value = string.match(current, "^(.*)=(.*)$")
                if not key then
                    local input_keys = vim.tbl_map(Util.match_key, input_kwargs)
                    local kwarg_keys = Util.subtract(completion.kwargs, input_keys)

                    -- stylua: ignore
                    local filtered = current == ""
                        and kwarg_keys
                        or vim.tbl_filter(Util.startswith(current), completion.kwargs)

                    return vim.tbl_map(Util.with_suffix("="), filtered)
                end

                -- "Grapple subcmd arg key=|"
                -- "Grapple subcmd arg key=val|"

                local kwarg_values = argument_lookup[key] or {}

                -- stylua: ignore
                local filtered = value == ""
                    and kwarg_values
                    or vim.tbl_filter(Util.startswith(value), kwarg_values)

                return vim.tbl_map(Util.with_prefix(key .. "="), filtered)
            end,
        }
    )
end

return Grapple
