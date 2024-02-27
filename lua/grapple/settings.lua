---@class grapple.settings
local Settings = {}
Settings.__index = Settings

---@class grapple.settings
local DEFAULT_SETTINGS = {

    ---@type string
    ---@diagnostic disable-next-line: param-type-mismatch
    save_path = vim.fs.joinpath(vim.fn.stdpath("data"), "grapple"),

    icons = true,

    ---@type string
    scope = "git_branch",

    scopes = {
        {
            name = "global",
            resolver = function()
                return "global", vim.uv.cwd()
            end,
        },
        {
            name = "cwd",
            cache = { event = "DirChanged" },
            resolver = function()
                return vim.uv.cwd(), vim.uv.cwd()
            end,
        },
        {
            name = "git",
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
            fallback = "git",
            cache = { event = { "BufEnter", "FocusGained" } },
            resolver = function()
                local git_files = vim.fs.find(".git", { upward = true, stop = vim.uv.os_homedir() })
                if #git_files == 0 then
                    return
                end

                local root = vim.fn.fnamemodify(git_files[1], ":h")

                local branch = vim.system({ "git", "symbolic-ref", "--short", "HEAD" }, { text = true }):wait()
                local branch = vim.trim(string.gsub(branch.stdout, "\n", ""))

                local id = string.format("%s:%s", root, branch)
                local path = root

                return id, path
            end,
        },
        {
            name = "lsp",
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

    ---@type grapple.tag.content.title_fn
    tag_title = function(scope)
        return scope.id
    end,

    ---@type grapple.tag.content.hook_fn
    tag_hook = function(window)
        local TagAction = require("grapple.tag_action")

        -- Select
        window:map("n", "<cr>", function()
            local cursor = window:cursor()
            local err = window:perform(TagAction.select, { index = cursor[1] })
            if err then
                vim.notify(err, vim.log.levels.ERROR)
            end
        end, { desc = "Select" })

        -- Quick select
        for i = 1, 9 do
            window:map("n", string.format("%s", i), function()
                local err = window:perform(TagAction.select, { index = i })
                if err then
                    vim.notify(err, vim.log.levels.ERROR)
                end
            end, { desc = string.format("Select %d", i) })
        end

        -- Quickfix list
        window:map("n", "<c-q>", function()
            local err = window:perform(TagAction.quickfix)
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

    ---@type grapple.vim.win_opts
    win_opts = {
        relative = "editor",
        width = 0.5,
        height = 10,
        row = 0.5,
        col = 0.5,
        border = "single",
        focusable = false,
        style = "minimal",
        title = "Grapple",
        title_pos = "center",
        title_padding = " ",
    },
}

function Settings:new()
    return setmetatable(DEFAULT_SETTINGS, self)
end

---@param opts? grapple.settings
function Settings:update(opts)
    self = vim.tbl_deep_extend("force", self, opts or {})
end

return Settings
