---@class grapple.settings
local Settings = {}

---@class grapple.settings
local DEFAULT_SETTINGS = {
    ---Grapple save location
    ---@type string
    ---@diagnostic disable-next-line: param-type-mismatch
    save_path = vim.fn.stdpath("data") .. "/" .. "grapple",

    ---Default scope to use when managing Grapple tags
    ---For more information, please see the Scopes section
    ---@type string
    scope = "git",

    ---User-defined scopes or overrides
    ---For more information about scopes, please see the Scope API section
    ---@type grapple.scope_definition[]
    scopes = {},

    ---Show icons next to tags in Grapple windows
    ---Requires "nvim-tree/nvim-web-devicons"
    ---@type boolean
    icons = true,

    ---Highlight the current selection in Grapple windows
    ---Also, indicates when a tag path does not exist
    ---@type boolean
    status = true,

    ---Position a tag's name should be shown in Grapple windows
    ---@type "start" | "end"
    name_pos = "end",

    ---How a tag's path should be rendered in Grapple windows
    ---  "relative": show tag path relative to the scope's resolved path
    ---  "basename": show tag path basename and directory hint
    ---See: settings.styles
    ---@type "basename" | "relative"
    style = "relative",

    ---A string of characters used for quick selecting in Grapple windows
    ---An empty string or false will disable quick select
    ---@type string | boolean
    quick_select = "123456789",

    ---Default command to use when selecting a tag
    ---@type fun(path: string)
    command = vim.cmd.edit,

    ---Time limit used for pruning unused scope (IDs). If a scope's save file
    ---modified time exceeds this limit, then it will be deleted when a prune
    ---requested. Can be an integer (in milliseconds) or a string time limit
    ---(e.g. "30d" or "2h" or "15m")
    ---@type integer | string
    prune = "30d",

    ---@class grapple.scope_definition
    ---@field name string
    ---@field force? boolean
    ---@field desc? string
    ---@field fallback? string name of scope to fall back on
    ---@field cache? grapple.cache.options | boolean
    ---@field resolver grapple.scope_resolver

    ---Default scopes provided by Grapple
    ---For more information about default scopes, please see the Scopes section
    ---Disable by setting scope to "false". For example, { lsp = false }
    ---@type table<string, grapple.scope_definition | boolean>
    default_scopes = {
        global = {
            name = "global",
            desc = "Global scope",
            resolver = function()
                return "global", vim.loop.cwd()
            end,
        },
        static = {
            name = "static",
            desc = "Initial working directory",
            cache = true,
            resolver = function()
                return vim.loop.cwd(), vim.loop.cwd()
            end,
        },
        cwd = {
            name = "cwd",
            desc = "Current working directory",
            cache = { event = "DirChanged" },
            resolver = function()
                return vim.loop.cwd(), vim.loop.cwd()
            end,
        },
        git = {
            name = "git",
            desc = "Git root directory",
            fallback = "cwd",
            cache = {
                event = { "BufEnter", "FocusGained" },
                debounce = 1000, -- ms
            },
            resolver = function()
                -- TODO: this will stop on submodules, needs fixing
                local git_files = vim.fs.find(".git", { upward = true, stop = vim.loop.os_homedir() })
                if #git_files == 0 then
                    return
                end

                local root = vim.fn.fnamemodify(git_files[1], ":h")

                return root, root
            end,
        },
        git_branch = {
            name = "git_branch",
            desc = "Git root directory and branch",
            fallback = "cwd",
            cache = {
                event = { "BufEnter", "FocusGained" },
                debounce = 1000, -- ms
            },
            resolver = function()
                -- TODO: this will stop on submodules, needs fixing
                local git_files = vim.fs.find(".git", { upward = true, stop = vim.loop.os_homedir() })
                if #git_files == 0 then
                    return
                end

                local root = vim.fn.fnamemodify(git_files[1], ":h")

                -- TODO: Don't use vim.system, it's a nvim-0.10 feature
                -- TODO: Don't shell out, read the git head or something similar
                local result = vim.fn.system({ "git", "symbolic-ref", "--short", "HEAD" })
                local branch = vim.trim(string.gsub(result, "\n", ""))

                local id = string.format("%s:%s", root, branch)
                local path = root

                return id, path
            end,
        },
        lsp = {
            name = "lsp",
            desc = "LSP root directory",
            fallback = "git",
            cache = {
                event = { "LspAttach", "LspDetach" },
                debounce = 250, -- ms
            },
            resolver = function()
                -- TODO: Don't use vim.lsp.get_clients, it's a nvim-0.10 feature
                local clients = vim.lsp.get_active_clients({ bufnr = 0 })
                if #clients == 0 then
                    return
                end

                local path = clients[1].root_dir

                return path, path
            end,
        },
    },

    ---User-defined tags title function for Grapple windows
    ---By default, uses the resolved scope's ID
    ---@type fun(scope: grapple.resolved_scope): string?
    tag_title = function(scope)
        local Path = require("grapple.path")

        -- If the scope ID is something like "global"
        if not Path.is_absolute(scope.id) then
            return scope.id
        end

        return vim.fn.fnamemodify(scope.id, ":~")
    end,

    ---Not user documented
    ---@type grapple.hook_fn
    tag_hook = function(window)
        local TagActions = require("grapple.tag_actions")
        local App = require("grapple.app")
        local app = App.get()

        -- Select
        window:map("n", "<cr>", function()
            local cursor = window:cursor()
            window:perform_close(TagActions.select, { index = cursor[1] })
        end, { desc = "Select" })

        -- Select (horizontal split)
        window:map("n", "<c-s>", function()
            local cursor = window:cursor()
            window:perform_close(TagActions.select, { index = cursor[1], command = vim.cmd.split })
        end, { desc = "Select (split)" })

        -- Select (vertical split)
        window:map("n", "|", function()
            local cursor = window:cursor()
            window:perform_close(TagActions.select, { index = cursor[1], command = vim.cmd.vsplit })
        end, { desc = "Select (vsplit)" })

        -- Quick select
        for i, quick in ipairs(app.settings:quick_select()) do
            window:map("n", string.format("%s", quick), function()
                window:perform_close(TagActions.select, { index = i })
            end, { desc = string.format("Quick select %d", i) })
        end

        -- Quickfix list
        window:map("n", "<c-q>", function()
            window:perform_close(TagActions.quickfix)
        end, { desc = "Quickfix" })

        -- Go "up" to scopes
        window:map("n", "-", function()
            window:perform_close(TagActions.open_scopes)
        end, { desc = "Go to scopes" })

        -- Rename
        window:map("n", "R", function()
            local entry = window:current_entry()
            local path = entry.data.path
            window:perform_retain(TagActions.rename, { path = path })
        end, { desc = "Rename" })

        -- Help
        window:map("n", "?", function()
            local WindowActions = require("grapple.window_actions")
            window:perform_retain(WindowActions.help)
        end, { desc = "Help" })
    end,

    ---User-defined scopes title function for Grapple windows
    ---By default, renders "Grapple Scopes"
    ---@type fun(): string?
    scope_title = function()
        return "Grapple Scopes"
    end,

    ---Not user documented
    ---@type grapple.hook_fn
    scope_hook = function(window)
        local ScopeActions = require("grapple.scope_actions")
        local App = require("grapple.app")
        local app = App.get()

        -- Select
        window:map("n", "<cr>", function()
            local entry = window:current_entry()
            local name = entry.data.name
            window:perform_close(ScopeActions.open_tags, { name = name })
        end, { desc = "Open scope" })

        -- Quick select
        for i, quick in ipairs(app.settings:quick_select()) do
            window:map("n", string.format("%s", quick), function()
                local entry, err = window:entry({ index = i })
                if not entry then
                    ---@diagnostic disable-next-line: param-type-mismatch
                    return vim.notify(err, vim.log.levels.ERROR)
                end

                local name = entry.data.name
                window:perform_close(ScopeActions.open_tags, { name = name })
            end, { desc = string.format("Quick open %d", i) })
        end

        -- Change
        window:map("n", "<s-cr>", function()
            local entry = window:current_entry()
            local name = entry.data.name
            window:perform_close(ScopeActions.change, { name = name })
        end, { desc = "Change scope" })

        -- Navigate "up" to loaded scopes
        window:map("n", "-", function()
            window:perform_close(ScopeActions.open_loaded)
        end, { desc = "Go to loaded scopes" })

        -- Help
        window:map("n", "?", function()
            local WindowActions = require("grapple.window_actions")
            window:perform_retain(WindowActions.help)
        end, { desc = "Help" })
    end,

    ---User-defined loaded scopes title function for Grapple windows
    ---By default, renders "Grapple Loaded Scopes"
    ---@type fun(): string?
    loaded_title = function()
        return "Grapple Loaded Scopes"
    end,

    ---Not user documented
    ---@type grapple.hook_fn
    loaded_hook = function(window)
        local ContainerActions = require("grapple.container_actions")
        local App = require("grapple.app")
        local app = App.get()

        -- Select
        window:map("n", "<cr>", function()
            local entry = window:current_entry()
            local id = entry.data.id
            window:perform_close(ContainerActions.select, { id = id })
        end, { desc = "Open tags" })

        -- Quick select
        for i, quick in ipairs(app.settings:quick_select()) do
            window:map("n", string.format("%s", quick), function()
                local entry, err = window:entry({ index = i })
                if not entry then
                    ---@diagnostic disable-next-line: param-type-mismatch
                    return vim.notify(err, vim.log.levels.ERROR)
                end

                local name = entry and entry.data.name
                window:perform_close(ContainerActions.select, { name = name })
            end, { desc = string.format("Quick select %d", i) })
        end

        -- Toggle
        window:map("n", "<s-cr>", function()
            window:perform_retain(ContainerActions.toggle_all)
        end, { desc = "Toggle show all" })

        -- Unload
        window:map("n", "x", function()
            local entry = window:current_entry()
            local id = entry.data.id
            window:perform_retain(ContainerActions.unload, { id = id })
        end)

        -- Reset
        window:map("n", "X", function()
            local entry = window:current_entry()
            local id = entry.data.id
            window:perform_retain(ContainerActions.reset, { id = id })
        end, { desc = "Reset scope" })

        -- Navigate "up" to scopes
        window:map("n", "-", function()
            window:perform_close(ContainerActions.open_scopes)
        end, { desc = "Go to scopes" })

        -- Help
        window:map("n", "?", function()
            local WindowActions = require("grapple.window_actions")
            window:perform_retain(WindowActions.help)
        end, { desc = "Help" })
    end,

    ---@alias grapple.content grapple.tag_content| grapple.scope_content| grapple.container_content
    ---@alias grapple.entity grapple.tag_content.entity | grapple.scope_content.entity | grapple.container_content.entity
    ---@alias grapple.style_fn fun(entity: grapple.entity, content: grapple.content): grapple.stylized

    ---@class grapple.stylized
    ---@field display string
    ---@field marks grapple.vim.mark[]

    ---Not user documented
    ---@type table<string, grapple.style_fn>
    styles = {
        relative = function(entity, content)
            local Path = require("grapple.path")

            ---@type grapple.stylized
            local line = {
                display = assert(Path.fs_relative(content.scope.path, entity.tag.path)),
                marks = {},
            }

            return line
        end,
        basename = function(entity, _)
            local Path = require("grapple.path")

            local parent_mark
            if not entity.base_unique then
                -- stylua: ignore
                parent_mark = {
                    virt_text = { {
                        "."
                            .. Path.separator
                            .. Path.relative(Path.parent(entity.tag.path, 3), Path.parent(entity.tag.path, 1)),
                        "GrappleHint",
                    } },
                    virt_text_pos = "eol",
                }
            end

            ---@type grapple.stylized
            local line = {
                display = Path.base(entity.tag.path),
                marks = { parent_mark },
            }

            return line
        end,
    },

    ---Additional window options for Grapple windows
    ---See :h nvim_open_win
    ---@type grapple.vim.win_opts
    win_opts = {
        -- Can be fractional
        width = 80,
        height = 12,
        row = 0.5,
        col = 0.5,

        relative = "editor",
        border = "single",
        focusable = false,
        style = "minimal",
        title_pos = "center",
        title = "Grapple",

        -- Custom: adds padding around window title
        title_padding = " ",
    },

    ---Values for which a buffer should be excluded from being tagged
    exclusions = {
        buftype = {
            "nofile",
        },

        filetype = {
            "grapple",
        },

        name = {
            "",
        },
    },

    ---Not user documented
    ---Default statusline options
    ---@class grapple.statusline.options
    statusline = {
        icon = "󰛢",
        inactive = " %s ",
        active = "[%s]",

        -- Mostly for lualine integration. Lualine will automatically prepend
        -- the icon to the returned output
        include_icon = true,
    },
}

Settings.__index = function(tbl, key)
    return Settings[key] or tbl.inner[key]
end

function Settings:new()
    return setmetatable({
        inner = vim.deepcopy(DEFAULT_SETTINGS),
    }, self)
end

---Override quick_select to ensure a string table is always returned
---@return string[]
---@diagnostic disable-next-line: assign-type-mismatch
function Settings:quick_select()
    local Util = require("grapple.util")

    if not self.inner.quick_select then
        return {}
    end

    return vim.tbl_filter(Util.not_empty, vim.split(self.inner.quick_select, ""))
end

---Override scopes to combine both the default scopes and user-defined scopes
---@return grapple.scope_definition[]
function Settings:scopes()
    -- HACK: Define the order so that fallbacks are defined first
    local default_order = {
        "global",
        "cwd",
        "git",
        "git_branch",
        "lsp",
    }

    local scopes = {}

    for _, name in ipairs(default_order) do
        local definition = self.inner.default_scopes[name]
        if definition == false then
            table.insert(scopes, { name = name, delete = true })
        elseif type(definition) == "table" then
            table.insert(scopes, self.inner.default_scopes[name])
        else
            error(string.format("invalid default scope: %s", vim.inspect(definition)))
        end
    end

    for _, definition in ipairs(self.inner.scopes) do
        table.insert(scopes, definition)
    end

    return scopes
end

-- Update settings in-place
---@param opts? grapple.settings
function Settings:update(opts)
    self.inner = vim.tbl_deep_extend("force", self.inner, opts or {})
end

return Settings
