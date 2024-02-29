---@class grapple.settings
local Settings = {}

---@class grapple.settings
local DEFAULT_SETTINGS = {
    ---Grapple save location
    ---@type string
    ---@diagnostic disable-next-line: param-type-mismatch
    save_path = vim.fs.joinpath(vim.fn.stdpath("data"), "grapple"),

    ---Show icons next to tags or scopes in Grapple windows
    ---@type boolean
    icons = true,

    ---Default scope to use when managing Grapple tags
    ---@type string
    scope = "git_branch",

    ---@class grapple.scope_definition
    ---@field name string
    ---@field desc? string
    ---@field fallback? string name of scope to fall back on
    ---@field cache? grapple.cache.options
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
                return "global", vim.uv.cwd()
            end,
        },
        {
            name = "static",
            desc = "Starting working directory",
            cache = true,
            resolver = function()
                return "static", vim.uv.cwd()
            end,
        },
        {
            name = "cwd",
            desc = "Current working directory",
            cache = { event = "DirChanged" },
            resolver = function()
                return vim.uv.cwd(), vim.uv.cwd()
            end,
        },
        {
            name = "git",
            desc = "Git root directory",
            fallback = "cwd",
            cache = { event = { "BufEnter", "FocusGained" } },
            resolver = function()
                local git_files = vim.fs.find(".git", { upward = true, stop = vim.uv.os_homedir() })
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
            cache = { event = { "BufEnter", "FocusGained" } },
            resolver = function()
                local git_files = vim.fs.find(".git", { upward = true, stop = vim.uv.os_homedir() })
                if #git_files == 0 then
                    return
                end

                local root = vim.fn.fnamemodify(git_files[1], ":h")

                local result = vim.system({ "git", "symbolic-ref", "--short", "HEAD" }, { text = true }):wait()
                local branch = vim.trim(string.gsub(result.stdout, "\n", ""))

                local id = string.format("%s:%s", root, branch)
                local path = root

                return id, path
            end,
        },
        {
            name = "lsp",
            desc = "LSP root directory",
            fallback = "git",
            cache = { event = { "LspAttach", "LspDetach" } },
            resolver = function()
                local clients = vim.lsp.get_clients({ bufnr = 0 })
                if #clients == 0 then
                    return
                end

                local path = clients[1].root_dir

                return path, path
            end,
        },
    },

    ---User-defined tag title function for Grapple windows
    ---By default, uses the resolved scope's ID
    ---@type fun(scope: grapple.resolved_scope): string?
    tag_title = function(scope)
        return scope.id
    end,

    ---Not user documented
    ---@type grapple.hook_fn
    tag_hook = function(window)
        local TagActions = require("grapple.tag_actions")

        -- Select
        window:map("n", "<cr>", function()
            local cursor = window:cursor()
            local err = window:perform(TagActions.select, { index = cursor[1] })
            if err then
                vim.notify(err, vim.log.levels.ERROR)
            end
        end, { desc = "Select" })

        -- Select (horizontal split)
        window:map("n", "-", function()
            local cursor = window:cursor()
            local err = window:perform(TagActions.select, { index = cursor[1], command = vim.cmd.split })
            if err then
                vim.notify(err, vim.log.levels.ERROR)
            end
        end, { desc = "Select (split)" })

        -- Select (vertical split)
        window:map("n", "|", function()
            local cursor = window:cursor()
            local err = window:perform(TagActions.select, { index = cursor[1], command = vim.cmd.vsplit })
            if err then
                vim.notify(err, vim.log.levels.ERROR)
            end
        end, { desc = "Select (vsplit)" })

        -- Quick select
        for i = 1, 9 do
            window:map("n", string.format("%s", i), function()
                local err = window:perform(TagActions.select, { index = i })
                if err then
                    vim.notify(err, vim.log.levels.ERROR)
                end
            end, { desc = string.format("Select %d", i) })
        end

        -- Quickfix list
        window:map("n", "<c-q>", function()
            local err = window:perform(TagActions.quickfix)
            if err then
                vim.notify(err, vim.log.levels.ERROR)
            end
        end, { desc = "Quickfix" })

        window:map("n", "<c-r>", function()
            local err = window:refresh()
            if err then
                vim.notify(err, vim.log.levels.ERROR)
            end
        end, { desc = "Refresh" })
    end,

    ---User-defined scope title function for Grapple windows
    ---By default, renders "Grapple Scopes"
    ---@type fun(): string?
    scope_title = function()
        return "Grapple Scopes"
    end,

    ---Not user documented
    ---@type grapple.hook_fn
    scope_hook = function(window)
        local ScopeActions = require("grapple.scope_actions")

        window:map("n", "<cr>", function()
            local entry = window:current_entry()
            local name = entry.data.name

            local err = window:perform(ScopeActions.select, { name = entry.data.name })
            if err then
                return vim.notify(err, vim.log.levels.ERROR)
            end

            vim.notify(string.format("Changed scope: %s", name))
        end, { desc = "Change scope" })
    end,

    ---User-defined container title function for Grapple windows
    ---By default, renders "Grapple Containers"
    ---@type fun(): string?
    container_title = function()
        return "Grapple Containers"
    end,

    ---Not user documented
    ---@type grapple.hook_fn
    container_hook = function(window) end,

    ---Additional window options for Grapple windows
    ---@type grapple.vim.win_opts
    win_opts = {
        relative = "editor",
        width = 0.5,
        height = 0.5,
        row = 0.5,
        col = 0.5,
        border = "single",
        focusable = false,
        style = "minimal",
        title_pos = "center",

        -- Custom: "{{ title }}" will use the tag_title or scope_title
        title = "{{ title }}",

        -- Custom: adds padding around window title
        title_padding = " ",
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
