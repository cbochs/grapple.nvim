local Grapple = {}

function Grapple.initialize()
    vim.api.nvim_create_augroup("Grapple", { clear = true })
    vim.api.nvim_create_autocmd({ "BufWinLeave" }, {
        pattern = "?*", -- non-empty file
        group = "Grapple",
        callback = function(opts)
            local Util = require("grapple.util")

            local app = Grapple.app()
            local buf_name = vim.api.nvim_buf_get_name(opts.buf)
            app.tag_manager:update({ path = buf_name })

            local err = app.state_manager:write("bufwinleave", {
                event = opts.event,
                event_file = opts.file,
                buf_id = opts.buf,
                buf_name = buf_name,
                cursor = Util.cursor(buf_name),
            })
            if err then
                vim.notify(err:error(), vim.log.levels.INFO)
            end
        end,
    })

    vim.api.nvim_create_autocmd({ "QuitPre" }, {
        pattern = "?*", -- non-empty file
        group = "Grapple",
        callback = function(opts)
            local Util = require("grapple.util")

            local app = Grapple.app()
            local buf_name = vim.api.nvim_buf_get_name(opts.buf)
            local ok, err = app.tag_manager:update({ path = buf_name })

            app.state_manager:write("quitpre", {
                a_ok = ok,
                b_err = err,
                c_event = opts.event,
                d_event_file = opts.file,
                e_buf_id = opts.buf,
                f_buf_name = buf_name,
                g_cursor = Util.cursor(buf_name),
            })
        end,
    })
end

local App = nil

---@return grapple.app
function Grapple.app()
    if App then
        return App
    end

    local ScopeManager = require("grapple.scope_manager")
    local StateManager = require("grapple.state_manager")
    local TagManager = require("grapple.tag_manager")

    local state_manager = StateManager:new("test_saves")
    local tag_manager = TagManager:new(state_manager)
    local scope_manager = ScopeManager:new(tag_manager)

    scope_manager:define("git_branch", function()
        local root = vim.system({ "git", "rev-parse", "--show-toplevel" }, { text = true }):wait()
        local root = vim.trim(string.gsub(root.stdout, "\n", ""))

        local branch = vim.system({ "git", "symbolic-ref", "--short", "HEAD" }, { text = true }):wait()
        local branch = vim.trim(string.gsub(branch.stdout, "\n", ""))

        local id = string.format("%s:%s", root, branch)
        local path = root

        return id, path
    end)

    ---@class grapple.app
    App = {
        scope_manager = scope_manager,
        state_manager = state_manager,
        tag_manager = tag_manager,
    }

    return App
end

function Grapple.tag()
    local app = Grapple.app()
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

function Grapple.select(opts)
    local app = Grapple.app()
    local scope, err = app.scope_manager:get_resolved("git_branch")
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = scope:enter(function(container)
        ---@diagnostic disable-next-line: redefined-local
        local tag, err = container:get(opts)
        if not tag then
            return err
        end

        ---@diagnostic disable-next-line: redefined-local
        local err = tag:select()
        if err then
            return err
        end
    end)

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

    local app = Grapple.app()
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
