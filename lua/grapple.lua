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
---@field scope? string

---@param opts? grapple.options
function Grapple.tag(opts)
    opts = opts or {}

    local app = require("grapple.app").get()
    app:enter(opts.scope, function(container)
        local path = opts.path or vim.api.nvim_buf_get_name(opts.buffer or 0)
        return container:insert({ path = path, index = opts.index })
    end)
end

---@param opts? grapple.options
function Grapple.untag(opts)
    opts = opts or {}

    local app = require("grapple.app").get()
    app:enter(opts.scope, function(container)
        local path = opts.path or vim.api.nvim_buf_get_name(opts.buffer or 0)
        return container:remove({ path = path, index = opts.index })
    end)
end

---@param opts? grapple.options
function Grapple.toggle(opts)
    opts = opts or {}

    local app = require("grapple.app").get()
    app:enter(opts.scope, function(container)
        local path = opts.path or vim.api.nvim_buf_get_name(opts.buffer or 0)
        if container:has(path) then
            return container:remove({ path = path })
        else
            return container:insert({ path = path })
        end
    end)
end

---@param opts? grapple.options
function Grapple.select(opts)
    local TagAction = require("grapple.tag_action")

    opts = opts or {}

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

---@param opts? grapple.options
function Grapple.cycle_forward(opts)
    Grapple.cycle("forward", opts)
end

---@param opts? grapple.options
function Grapple.cycle_backward(opts)
    Grapple.cycle("backward", opts)
end

---@param direction "forward" | "backward"
---@param opts? grapple.options
function Grapple.cycle(direction, opts)
    opts = opts or {}

    local app = require("grapple.app").get()
    app:enter(opts.scope, function(container)
        if container:is_empty() then
            return
        end

        local path = opts.path or vim.api.nvim_buf_get_name(opts.buffer or 0)

        -- Fancy maths to get the next index for a given direction
        -- 1. Change to 0-based indexing
        -- 2. Perform index % container length, being careful of negative values
        -- 3. Change back to 1-based indexing
        local index = container:find({ path = path, index = opts.index }) or 1
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

---@param scope_name? string
function Grapple.open_tags(scope_name)
    local TagContent = require("grapple.tag_content")
    local Window = require("grapple.window")

    local app = require("grapple.app").get()
    local scope, err = app.scope_manager:get_resolved(scope_name or app.settings.scope)
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

function Grapple.open_scopes()
    local ScopeContent = require("grapple.scope_content")
    local Window = require("grapple.window")

    local app = require("grapple.app").get()
    local window = Window:new(app.settings.win_opts)
    local content = ScopeContent:new(app.scope_manager, app.settings.scope_hook, app.settings.scope_title)

    window:open()
    window:attach(content)

    ---@diagnostic disable-next-line: redefined-local
    local err = window:render()
    if err then
        vim.notify(err, vim.log.levels.ERROR)
    end
end

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
            local action = opts.fargs[1]
            local args = {}
            local kwargs = {}

            for _, arg in ipairs({ unpack(opts.fargs, 2) }) do
                local key, value = string.match(arg, "^(.*)=(.*)$")
                if not key then
                    table.insert(args, tonumber(arg) or arg)
                else
                    kwargs[key] = tonumber(value) or value
                end
            end

            Grapple[action](unpack(args), unpack(kwargs))
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

return Grapple
