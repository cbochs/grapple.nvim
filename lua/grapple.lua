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

    vim.api.nvim_create_user_command(
        "Grapple",

        ---@param opts grapple.vim.user_command
        function(opts)
            local Util = require("grapple.util")

            local action = opts.fargs[1]

            local args = Util.reduce({ unpack(opts.fargs, 2) }, function(args, arg)
                local key, value = string.match(arg, "^(.*)=(.*)$")
                args[key] = value
                return args
            end, {})

            Grapple[action](args)
        end,
        { desc = "Grapple", nargs = "*" }
    )
end

---@param opts? grapple.settings
function Grapple.setup(opts)
    local app = require("grapple.app").get()

    vim.print("Setting up grapple")

    app.settings:update(opts)

    if app.settings.load_on_start then
        app:load_current_scope()
    end
end

---@class grapple.spec.tag
---@field buffer? integer
---@field path? string
---@field index? integer

---@param opts? grapple.spec.tag
function Grapple.tag(opts)
    local app = require("grapple.app").get()
    local scope, err = app:current_scope()
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = scope:enter(function(container)
        return container:insert({ path = vim.api.nvim_buf_get_name(0) })
    end)

    if err then
        vim.notify(err, vim.log.levels.WARN)
    end
end

---@param opts? grapple.spec.tag
function Grapple.untag(opts)
    local app = require("grapple.app").get()
    local scope, err = app:current_scope()
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = scope:enter(function(container)
        return container:remove({ path = vim.api.nvim_buf_get_name(0) })
    end)

    if err then
        vim.notify(err, vim.log.levels.WARN)
    end
end

---@param opts grapple.spec.tag
function Grapple.toggle(opts)
    local app = require("grapple.app").get()
    local scope, err = app:current_scope()
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = scope:enter(function(container)
        local buf_name = vim.api.nvim_buf_get_name(0)
        if container:has(buf_name) then
            return container:remove({ path = buf_name })
        else
            return container:insert({ path = buf_name })
        end
    end)

    if err then
        vim.notify(err, vim.log.levels.WARN)
    end
end

---@param opts grapple.tag.container.get
function Grapple.select(opts)
    local TagAction = require("grapple.tag_action")
    local app = require("grapple.app").get()

    local scope, err = app:current_scope()
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = TagAction.select(scope, opts)
    if err then
        return vim.notify(err, vim.log.levels.ERROR)
    end
end

function Grapple.open_tags()
    local TagContent = require("grapple.tag_content")
    local Window = require("grapple.window")

    local app = require("grapple.app").get()
    local scope, err = app:current_scope()
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    local window = Window:new(app.settings.win_opts)
    local content = TagContent:new(scope, app.settings.tag_hook, app.settings.tag_title)

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
