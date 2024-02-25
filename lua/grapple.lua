local Grapple = {}

function Grapple.initialize()
    vim.api.nvim_create_augroup("Grapple", { clear = true })
    vim.api.nvim_create_autocmd({ "BufWinLeave", "QuitPre" }, {
        pattern = "?*", -- non-empty file
        group = "Grapple",
        callback = function(opts)
            local app = require("grapple.app").get()
            local buf_name = vim.api.nvim_buf_get_name(opts.buf)
            app.tag_manager:update({ path = buf_name })
        end,
    })

    local app = require("grapple.app").get()

    app.scope_manager:define("global", function()
        return "global", vim.uv.cwd()
    end)

    app.scope_manager:define("cwd", function()
        local cwd = vim.uv.cwd()

        -- stylua: ignore
        if not cwd then return end

        return cwd, cwd
    end)

    app.scope_manager:define("git_branch", function()
        -- TODO: exit early if not in .git

        local root = vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true }):wait()
        local root = vim.trim(string.gsub(root.stdout, "\n", ""))

        local branch = vim.system({ "git", "symbolic-ref", "--short", "HEAD" }, { text = true }):wait()
        local branch = vim.trim(string.gsub(branch.stdout, "\n", ""))

        local id = string.format("%s:%s", root, branch)
        local path = root

        return id, path
    end, { fallback = "cwd" })

    local scope = app.scope_manager:get_resolved("git_branch")
    app.tag_manager:load(scope.id)
end

function Grapple.tag()
    local app = require("grapple.app").get()
    local scope, err = app.scope_manager:get_resolved("git_branch")
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    scope:enter(function(container)
        ---@diagnostic disable-next-line: redefined-local
        local _, err = container:insert({ path = vim.api.nvim_buf_get_name(0) })
        if err then
            vim.notify(err, vim.log.levels.WARN)
        end
    end)
end

function Grapple.untag() end

---@param opts grapple.tag.container.get
function Grapple.select(opts)
    local app = require("grapple.app").get()

    local scope, err = app.scope_manager:get_resolved("git_branch")
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    local TagAction = require("grapple.tag_action")

    ---@diagnostic disable-next-line: redefined-local
    local err = TagAction.select(scope, opts)
    if err then
        vim.notify(err, vim.log.levels.WARN)
    end
end

function Grapple.open_tags()
    local TagAction = require("grapple.tag_action")
    local TagContent = require("grapple.tag_content")
    local Window = require("grapple.window")

    local win_opts = {
        relative = "editor",
        width = 0.5,
        height = 0.5,
        row = 0.5,
        col = 0.5,
        style = "minimal",
        focusable = false,
        border = "single",
        title_pos = "center",
    }

    ---@type grapple.tag.content.hook_fn
    local hook_fn = function(window)
        -- Select
        window:map("n", "<cr>", function()
            local cursor = window:cursor()
            local err = window:perform(TagAction.select, { index = cursor[1] })
            if err then
                vim.notify(err, vim.log.levels.ERROR)
            end
        end)

        -- Quick select
        for i = 1, 9 do
            window:map("n", string.format("%s", i), function()
                local err = window:perform(TagAction.select, { index = i })
                if err then
                    vim.notify(err, vim.log.levels.ERROR)
                end
            end)
        end

        -- Quickfix list
        window:map("n", "<c-q>", function()
            local err = window:perform(TagAction.quickfix)
            if err then
                vim.notify(err, vim.log.levels.ERROR)
            end
        end)

        window:map("n", "<c-r>", function()
            local err = window:refresh()
            if err then
                vim.notify(err, vim.log.levels.ERROR)
            end
        end)
    end

    ---@type grapple.tag.content.title_fn
    local title_fn = function(scope)
        return scope.id
    end

    local app = require("grapple.app").get()
    local scope, err = app.scope_manager:get_resolved("git_branch")
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    local content = TagContent:new(scope, hook_fn, title_fn)
    local window = Window:new(win_opts)

    window:open()
    window:attach(content)

    ---@diagnostic disable-next-line: redefined-local
    local err = window:render()
    if err then
        vim.notify(err, vim.log.levels.ERROR)
    end
end

function Grapple.open_scopes() end

return Grapple
