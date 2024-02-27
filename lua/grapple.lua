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
                args[key] = tonumber(value) or value
                return args
            end, {})

            Grapple[action](args)
        end,
        {
            desc = "Grapple",
            nargs = "*",
            complete = function(current, command, index)
                -- TODO: implement
                -- "current" gives the current argument the user is writing (can be partial)
                -- "command" gives the entire command line
                -- "index" gives the cursor location
            end,
        }
    )
end

---@param opts? grapple.settings
function Grapple.setup(opts)
    local app = require("grapple.app").get()
    app.settings:update(opts)
    app:load_current_scope()
end

---@param opts? { buffer?: integer, path?: string, index?: integer }
function Grapple.tag(opts)
    opts = opts or {}

    local app = require("grapple.app").get()
    local scope, err = app:current_scope()
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = scope:enter(function(container)
        local path = opts.path or vim.api.nvim_buf_get_name(opts.buffer or 0)
        return container:insert({ path = path, index = opts.index })
    end)

    if err then
        vim.notify(err, vim.log.levels.WARN)
    end
end

---@param opts? { buffer?: integer, path?: string, index?: integer }
function Grapple.untag(opts)
    opts = opts or {}

    local app = require("grapple.app").get()
    local scope, err = app:current_scope()
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = scope:enter(function(container)
        local path = opts.path or vim.api.nvim_buf_get_name(opts.buffer or 0)
        return container:remove({ path = path, index = opts.index })
    end)

    if err then
        vim.notify(err, vim.log.levels.WARN)
    end
end

---@param opts? { buffer?: integer, path?: string }
function Grapple.toggle(opts)
    opts = opts or {}

    local app = require("grapple.app").get()
    local scope, err = app:current_scope()
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = scope:enter(function(container)
        local path = opts.path or vim.api.nvim_buf_get_name(opts.buffer or 0)
        if container:has(path) then
            return container:remove({ path = path })
        else
            return container:insert({ path = path })
        end
    end)

    if err then
        vim.notify(err, vim.log.levels.WARN)
    end
end

---@param opts? { buffer?: integer, path?: string, index?: integer }
function Grapple.select(opts)
    opts = opts or {}

    local TagAction = require("grapple.tag_action")

    local app = require("grapple.app").get()
    local scope, err = app:current_scope()
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    local path = opts.path or vim.api.nvim_buf_get_name(opts.buffer or 0)

    ---@diagnostic disable-next-line: redefined-local
    local err = TagAction.select(scope, { path = path, index = opts.index })
    if err then
        return vim.notify(err, vim.log.levels.ERROR)
    end
end

function Grapple.cycle_forward()
    Grapple.cycle("forward")
end

function Grapple.cycle_backward()
    Grapple.cycle("backward")
end

---@param direction? "forward" | "backward"
function Grapple.cycle(direction)
    local app = require("grapple.app").get()
    local scope, err = app:current_scope()
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = scope:enter(function(container)
        if container:is_empty() then
            return
        end

        local path = vim.api.nvim_buf_get_name(0)

        -- Fancy maths to get the next index for a given direction
        -- 1. Change to 0-based indexing
        -- 2. Perform index % container length, being careful of negative values
        -- 3. Change back to 1-based indexing
        local index = (container:index(path) or 1) - 1
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
