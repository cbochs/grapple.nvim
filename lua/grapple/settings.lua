---@class grapple.settings
local Settings = {}

---@class grapple.settings
local DEFAULT_SETTINGS = {
    ---Grapple save location
    ---@type string
    ---@diagnostic disable-next-line: param-type-mismatch
    save_path = vim.fn.stdpath("data") .. "/" .. "grapple",

    ---Show icons next to tags in Grapple windows
    ---@type boolean
    icons = true,

    ---Highlight the current selection in Grapple windows
    ---Also, indicates when a tag path does not exist
    ---@type boolean
    status = true,

    ---Default scope to use when managing Grapple tags
    ---@type string
    scope = "git",

    ---@class grapple.scope_definition
    ---@field name string
    ---@field force? boolean
    ---@field desc? string
    ---@field fallback? string name of scope to fall back on
    ---@field cache? grapple.cache.options | boolean
    ---@field resolver grapple.scope_resolver

    ---User-defined scopes or overrides
    ---For more information, please see the Scopes section
    ---@type grapple.scope_definition[]
    scopes = {},

    ---Default scopes provided by Grapple
    ---@type grapple.scope_definition[]
    default_scopes = {
        {
            name = "global",
            desc = "Global scope",
            resolver = function()
                return "global", vim.loop.cwd()
            end,
        },
        {
            name = "static",
            desc = "Initial working directory",
            cache = true,
            resolver = function()
                return vim.loop.cwd(), vim.loop.cwd()
            end,
        },
        {
            name = "cwd",
            desc = "Current working directory",
            cache = { event = "DirChanged" },
            resolver = function()
                return vim.loop.cwd(), vim.loop.cwd()
            end,
        },
        {
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
        {
            name = "git_branch",
            desc = "Git root directory and branch",
            fallback = "git",
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
        {
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

        -- Select
        window:map("n", "<cr>", function()
            local cursor = window:cursor()
            window:perform(TagActions.select, { index = cursor[1] })
        end, { desc = "Select" })

        -- Select (horizontal split)
        window:map("n", "<c-v>", function()
            local cursor = window:cursor()
            window:perform(TagActions.select, { index = cursor[1], command = vim.cmd.split })
        end, { desc = "Select (split)" })

        -- Select (vertical split)
        window:map("n", "|", function()
            local cursor = window:cursor()
            window:perform(TagActions.select, { index = cursor[1], command = vim.cmd.vsplit })
        end, { desc = "Select (vsplit)" })

        -- Quick select
        for i = 1, 9 do
            window:map("n", string.format("%s", i), function()
                window:perform(TagActions.select, { index = i })
            end, { desc = string.format("Select %d", i) })
        end

        -- Quickfix list
        window:map("n", "<c-q>", function()
            window:perform(TagActions.quickfix)
        end, { desc = "Quickfix" })

        -- Go "up" to scopes
        window:map("n", "-", function()
            window:perform(TagActions.open_scopes)
        end)
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

        -- Select
        window:map("n", "<cr>", function()
            local entry = window:current_entry()
            local name = entry.data.name
            window:perform(ScopeActions.select, { name = name })
            vim.notify(string.format("Changing scope: %s", name))
        end, { desc = "Change scope" })

        -- Quick select
        for i = 1, 9 do
            window:map("n", string.format("%s", i), function()
                local entry, err = window:entry({ index = i })
                if not entry then
                    ---@diagnostic disable-next-line: param-type-mismatch
                    return vim.notify(err, vim.log.levels.ERROR)
                end

                local name = entry.data.name
                window:perform(ScopeActions.select, { name = name })
            end, { desc = string.format("Select %d", i) })
        end

        -- Navigate "up" to loaded scopes
        window:map("n", "-", function()
            window:perform(ScopeActions.open_loaded)
        end, { desc = "Go to loaded scopes" })
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

        -- Select
        window:map("n", "<cr>", function()
            local entry = window:current_entry()
            local id = entry.data.id
            window:perform(ContainerActions.select, { id = id })
        end, { desc = "Open tags" })

        -- Quick select
        for i = 1, 9 do
            window:map("n", string.format("%s", i), function()
                local entry, err = window:entry({ index = i })
                if not entry then
                    ---@diagnostic disable-next-line: param-type-mismatch
                    return vim.notify(err, vim.log.levels.ERROR)
                end

                local name = entry and entry.data.name
                window:perform(ContainerActions.select, { name = name })
            end, { desc = string.format("Select %d", i) })
        end

        -- Reset
        window:map("n", "x", function()
            local entry = window:current_entry()
            local id = entry.data.id
            window:perform(ContainerActions.reset, { id = id })
        end, { desc = "Reset scope" })

        -- Navigate "up" to scopes
        window:map("n", "-", function()
            window:perform(ContainerActions.open_scopes)
        end)
    end,

    ---Additional window options for Grapple windows
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

        -- Custom: "{{ title }}" will use the tag_title or scope_title
        title = "{{ title }}",

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
}

Settings.__index = function(tbl, key)
    return Settings[key] or tbl.inner[key]
end

function Settings:new()
    return setmetatable({
        inner = vim.deepcopy(DEFAULT_SETTINGS),
    }, self)
end

-- Update settings in-place
---@param opts? grapple.settings
function Settings:update(opts)
    self.inner = vim.tbl_deep_extend("force", self.inner, opts or {})
end

return Settings
