---Initialize Grapple. Sets up autocommands to watch tagged files and creates the

---"Grapple" user command. Called only once when plugin is loaded.
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
        require("grapple").touch({ buffer = opts.buf })
    end,
})

-- Create top-level user command. Basically a wrapper around the lua API
vim.api.nvim_create_user_command(
    "Grapple",

    ---@param opts grapple.vim.user_command
    function(opts)
        local Grapple = require("grapple")

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
            local Grapple = require("grapple")
            local Util = require("grapple.util")

            local app = Grapple.app()

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
                cycle_scopes   = { args = { "direction" }, kwargs = { "scope", "all" } },
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
                scope = vim.tbl_map(Util.pick("name"), app:list_scopes()),
                style = Util.sort(vim.tbl_keys(app.settings.styles), Util.as_lower),
            }

            -- API methods which are not actionable
            local excluded_subcmds = {
                -- Deprecated
                "cycle",
                "cycle_backward",
                "cycle_forward",

                "app",
                "define_scope",
                "delete_scope",
                "exists",
                "find",
                "name_or_index",
                "setup",
                "statusline",
                "tags",
                "touch",
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
                local missing = Util.add(Util.subtract(subcmds, check), Util.subtract(check, subcmds))
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
