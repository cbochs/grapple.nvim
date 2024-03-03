local Grapple = {}

---@param opts? grapple.settings
function Grapple.setup(opts)
    local app = require("grapple.app").get()
    app.settings:update(opts)
    app:load_current_scope()
end

---@class grapple.options
---@field buffer? integer
---@field path? string
---@field name? string
---@field index? integer
---@field cursor? integer[]
---@field scope? string
---@field command? function undocumented

---Extract a valid path from the provided path or buffer options.
---@param opts grapple.options
---@return string | nil path, string? error
local function extract_path(opts)
    local App = require("grapple.app")
    local app = App.get()

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
    app:enter_with_save(opts.scope, function(container)
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

---Open the quickfix window populated with paths from a given scope
---By default, uses the current scope
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

---Select the next available tag for a given scope
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.cycle_forward(opts)
    Grapple.cycle("forward", opts)
end

---Select the previous available tag for a given scope
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.cycle_backward(opts)
    Grapple.cycle("backward", opts)
end

-- Cycle through and select the next or previous available tag for a given scope.
---By default, uses the current scope
---@param direction "forward" | "backward"
---@param opts? grapple.options
function Grapple.cycle(direction, opts)
    opts = opts or {}

    local app = require("grapple.app").get()
    app:enter_with_save(opts.scope, function(container)
        if container:is_empty() then
            return
        end

        local path, _ = extract_path(opts)
        opts.path = path

        -- Fancy maths to get the next index for a given direction
        -- 1. Change to 0-based indexing
        -- 2. Perform index % container length, being careful of negative values
        -- 3. Change back to 1-based indexing
        local index = (container:find(opts) or 1) - 1
        local next_direction = direction == "forward" and 1 or -1
        local next_index = math.fmod(index + next_direction + container:len(), container:len()) + 1

        ---@diagnostic disable-next-line: redefined-local
        local tag, err = container:get({ index = next_index })
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

---Return if a tag exists. Used for statusline components
---@param opts? grapple.options
function Grapple.exists(opts)
    local App = require("grapple.app")

    opts = opts or {}

    local exists = false
    local app = App.get()
    app:enter_without_save(opts.scope, function(container)
        local path, _ = extract_path(opts)
        opts.path = path

        exists = container:has(opts)
    end)

    return exists
end

---Return the name or index of a tag. Used for statusline components
---@param opts? grapple.options
---@return string | integer | nil
function Grapple.name_or_index(opts)
    local App = require("grapple.app")

    opts = opts or {}

    ---@type string | integer | nil
    local name_or_index

    local app = App.get()
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

local deprecated_once = false

---Deprecated. Return the name or index of a tag. Same as Grapple.name_or_index
---@return string | integer | nil
function Grapple.key()
    if not deprecated_once then
        deprecated_once = true
        vim.notify(
            "Grapple.key is deprecated. Use Grapple.name_or_index or Grapple.statusline instead",
            vim.log.levels.WARN
        )
    end
    return Grapple.name_or_index()
end

---Return a formatted string to be displayed on the statusline
---@return string | nil
function Grapple.statusline()
    local App = require("grapple.app")
    local app = App.get()
    local icon = app.settings.icons and "󰛢 " or ""

    local key = Grapple.name_or_index()
    if key then
        return icon .. key
    end
end

---Return the tags for a given scope. Used for integrations
---@param opts? { scope?: string }
---@return grapple.tag[] | nil, string? error
function Grapple.tags(opts)
    local App = require("grapple.app")

    opts = opts or {}

    local app = App.get()
    local scope, err = app.scope_manager:get_resolved(opts.scope or app.settings.scope)
    if not scope then
        return nil, err
    end

    ---@diagnostic disable-next-line: redefined-local
    local tags, err = scope:tags()
    if not tags then
        return nil, err
    end

    return tags, nil
end

---Clear all tags for a given scope
---By default, uses the current scope
---@param opts? { scope?: string, id?: string }
function Grapple.reset(opts)
    local App = require("grapple.app")

    opts = opts or {}

    local app = App.get()

    ---@type string
    local id
    if opts.id then
        id = opts.id
    else
        local scope, err = app.scope_manager:get_resolved(opts.scope or app.settings.scope)
        if not scope then
            ---@diagnostic disable-next-line: param-type-mismatch
            return vim.notify(err, vim.log.levels.ERROR)
        end

        id = scope.id
    end

    if not id then
        return vim.notify(string.format("must provide a valid scope or id: %s", vim.inspect(opts)))
    end

    local err = app.tag_manager:reset(id)
    if err then
        vim.notify(err, vim.log.levels.ERROR)
    end
end

---Create a user-defined scope
---@param definition grapple.scope_definition
function Grapple.define_scope(definition)
    local App = require("grapple.app")
    local app = App.get()
    app:define_scope(definition)
end

---Change the currently selected scope
---@param scope string
function Grapple.use_scope(scope)
    local App = require("grapple.app")
    local app = App.get()

    local resolved, err = app.scope_manager:get(scope)
    if not resolved then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    if resolved.name ~= app.settings.scope then
        app.settings:update({ scope = resolved.name })
        vim.notify(string.format("Changing scope: %s", resolved.name))
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

---Toggle a floating window populated with all tags for a given scope
---By default, uses the current scope
---@param opts? { scope?: string, id?: string }
function Grapple.toggle_tags(opts)
    toggle(Grapple.open_tags, opts)
end

---Open a floating window populated with all tags for a given scope
---By default, uses the current scope
---@param opts? { scope?: string, id?: string }
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

    local content = TagContent:new(scope, app.settings.tag_hook, app.settings.tag_title)

    open(content)
end

---Toggle a floating window populated with all defined scopes
function Grapple.toggle_scopes()
    toggle(Grapple.open_scopes)
end

---Open a floating window populated with all defined scopes
function Grapple.open_scopes()
    local App = require("grapple.app")
    local ScopeContent = require("grapple.scope_content")

    local app = App.get()
    local content = ScopeContent:new(app.scope_manager, app.settings.scope_hook, app.settings.scope_title)

    open(content)
end

---Toggle a floating window populated with all loaded scopes
function Grapple.toggle_loaded()
    toggle(Grapple.open_loaded)
end

---Open a floating window populated with all loaded scopes
function Grapple.open_loaded()
    local App = require("grapple.app")
    local ContainerContent = require("grapple.container_content")

    local app = App.get()
    local content = ContainerContent:new(app.tag_manager, app.settings.loaded_hook, app.settings.loaded_title)

    open(content)
end

---Initialize Grapple. Sets up autocommands to watch tagged files and creates the
---"Grapple" user command. Called only once when plugin is loaded.
function Grapple.initialize()
    -- Create highlights for Grapple windows
    vim.cmd("highlight default GrappleBold gui=bold cterm=bold")
    vim.cmd("highlight default GrappleCurrentBold gui=bold cterm=bold")

    vim.cmd("highlight default link GrappleNoExist DiagnosticError")
    vim.cmd("highlight default link GrappleCurrent SpecialChar")
    vim.cmd("highlight! link GrappleCurrentBold GrappleCurrent")

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

    -- Create top-level user command
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

                local tag_kwargs = { "buffer", "path", "name", "index", "cursor", "scope", "command" }
                local use_kwargs = Util.subtract(tag_kwargs, { "cursor" })
                local new_kwargs = Util.subtract(tag_kwargs, { "command" })
                local scope_kwargs = { "scope", "id" }

                -- stylua: ignore
                -- Lookup table of API functions and their available arguments
                local subcommand_lookup = {
                    clear_cache    = { args = { "scope" },     kwargs = {} },
                    cycle          = { args = { "direction" }, kwargs = use_kwargs },
                    cycle_backward = { args = {},              kwargs = use_kwargs },
                    cycle_forward  = { args = {},              kwargs = use_kwargs },
                    open_loaded    = { args = {},              kwargs = {} },
                    open_scopes    = { args = {},              kwargs = {} },
                    open_tags      = { args = {},              kwargs = scope_kwargs },
                    quickfix       = { args = {},              kwargs = scope_kwargs },
                    reset          = { args = {},              kwargs = scope_kwargs },
                    select         = { args = {},              kwargs = use_kwargs },
                    tag            = { args = {},              kwargs = new_kwargs },
                    toggle         = { args = {},              kwargs = tag_kwargs },
                    toggle_loaded  = { args = {},              kwargs = {} },
                    toggle_scopes  = { args = {},              kwargs = {} },
                    toggle_tags    = { args = {},              kwargs = scope_kwargs },
                    untag          = { args = {},              kwargs = use_kwargs },
                    use_scope      = { args = { "scope" },     kwargs = {} },
                }

                -- Lookup table of known arguments and their known values
                local argument_lookup = {
                    direction = { "forward", "backward" },
                    scope = Util.sort(vim.tbl_keys(app.scope_manager.scopes), Util.as_lower),
                }

                -- API functions which are not actionable
                local excluded_subcmds = {
                    "define_scope",
                    "exists",
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
                local input = vim.split(command, " ")
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
                    local kwarg_keys = completion.kwargs

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

    -- Add deprecated commands
    vim.api.nvim_create_user_command("GrappleTag", function(_)
        vim.notify('GrappleTag is deprecated. Use "Grapple tag" instead', vim.log.levels.WARN)
    end, { desc = "(Deprecated) Tag a buffer", nargs = "*" })

    vim.api.nvim_create_user_command("GrappleUntag", function(_)
        vim.notify('GrappleUntag is deprecated. Use "Grapple untag" instead', vim.log.levels.WARN)
    end, { desc = "(Deprecated) Untag a buffer", nargs = "*" })

    vim.api.nvim_create_user_command("GrappleToggle", function(_)
        vim.notify('GrappleToggle is deprecated. Use "Grapple toggle" instead', vim.log.levels.WARN)
    end, { desc = "(Deprecated) toggle a buffer", nargs = "*" })

    vim.api.nvim_create_user_command("GrappleSelect", function(_)
        vim.notify('GrappleSelect is deprecated. Use "Grapple select" instead', vim.log.levels.WARN)
    end, { desc = "(Deprecated) Select a tag", nargs = "*" })

    vim.api.nvim_create_user_command("GrappleCycle", function(_)
        vim.notify('GrappleCycle is deprecated. Use "Grapple cycle" instead', vim.log.levels.WARN)
    end, { desc = "(Deprecated) Cycles through scoped tags", nargs = "*" })

    vim.api.nvim_create_user_command("GrappleTags", function(_)
        vim.notify('GrappleTags is deprecated. Use "Grapple open_tags" instead', vim.log.levels.WARN)
    end, { desc = "(Deprecated) Get all scoped tags" })

    vim.api.nvim_create_user_command("GrappleReset", function(_)
        vim.notify('GrappleReset is deprecated. Use "Grapple reset" instead', vim.log.levels.WARN)
    end, { desc = "(Deprecated) Reset scoped tags" })

    vim.api.nvim_create_user_command("GrapplePopup", function(_)
        vim.notify(
            'GrapplePopup is deprecated. Use "Grapple open_tags", "Grapple open_scopes", or "Grapple open_containers" instead',
            vim.log.levels.WARN
        )
    end, { desc = "(Deprecated) Opens the grapple popup menu", nargs = "*" })
end

return Grapple
