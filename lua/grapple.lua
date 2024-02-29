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
---@field cursor? integer[]
---@field scope? string

---Create a new tag or update an existing tag on a path, URI, or buffer
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.tag(opts)
    local App = require("grapple.app")

    opts = opts or {}

    local app = App.get()
    app:enter_with_save(opts.scope, function(container)
        opts.path = opts.path or vim.api.nvim_buf_get_name(opts.buffer or 0)
        return container:insert(opts)
    end)
end

---Delete a tag on a path, URI, or buffer
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.untag(opts)
    local App = require("grapple.app")

    opts = opts or {}

    local app = App.get()
    app:enter_with_save(opts.scope, function(container)
        opts.path = opts.path or vim.api.nvim_buf_get_name(opts.buffer or 0)
        return container:remove(opts)
    end)
end

---Toggle a tag on a path, URI, or buffer. Lookup is done by index, name, path, or buffer
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.toggle(opts)
    local App = require("grapple.app")

    opts = opts or {}

    local app = App.get()
    app:enter_with_save(opts.scope, function(container)
        opts.path = opts.path or vim.api.nvim_buf_get_name(opts.buffer or 0)
        if container:has(opts) then
            return container:remove(opts)
        else
            return container:insert(opts)
        end
    end)
end

---Select a tag by index, name, path, or buffer
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.select(opts)
    local App = require("grapple.app")

    opts = opts or {}

    local app = App.get()
    app:enter_with_save(opts.scope, function(container)
        opts.path = opts.path or vim.api.nvim_buf_get_name(opts.buffer or 0)
        local index, err = container:find(opts)
        if not index then
            return err
        end

        local tag = assert(container:get({ index = index }))
        tag:select()
    end)
end

---Open the quickfix window populated with paths from a given scope
---By default, uses the current scope
---@param scope_name? string
function Grapple.quickfix(scope_name)
    local App = require("grapple.app")
    local TagActions = require("grapple.tag_actions")

    local app = App.get()
    local scope, err = app.scope_manager:get_resolved(scope_name or app.settings.scope)
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = TagActions.quickfix({ scope = scope })
    if err then
        return vim.notify(err, vim.log.levels.ERROR)
    end
end

---Select the next available tag for a given scope
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.cycle_forward(opts)
    Grapple.cycle("forward", opts)
end

---Select the previous available tag for a given scope
---By default, uses the current scope
---@param opts? grapple.options
function Grapple.cycle_backward(opts)
    Grapple.cycle("backward", opts)
end

---Cycles through a given scope's tags
---By default, uses the current scope
---@param direction "forward" | "backward"
---@param opts? grapple.options
function Grapple.cycle(direction, opts)
    opts = opts or {}

    local app = require("grapple.app").get()
    app:enter_with_save(opts.scope, function(container)
        if container:is_empty() then
            return
        end

        opts.path = opts.path or vim.api.nvim_buf_get_name(opts.buffer or 0)

        -- Fancy maths to get the next index for a given direction
        -- 1. Change to 0-based indexing
        -- 2. Perform index % container length, being careful of negative values
        -- 3. Change back to 1-based indexing
        local index = (container:find(opts) or 1) - 1
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

---@param opts? grapple.options
function Grapple.exists(opts)
    local App = require("grapple.app")

    opts = opts or {}

    local exists = false
    local app = App.get()
    app:enter_without_save(opts.scope, function(container)
        exists = container:has(opts)
    end)

    return exists
end

function Grapple.name_or_index(opts)
    local App = require("grapple.app")

    opts = opts or {}

    local name_or_index
    local app = App.get()
    app:enter_without_save(opts.scope, function(container)
        local tag = container:get(opts)
        if tag then
            name_or_index = tag.name or assert(container:find(opts))
        end
    end)

    return name_or_index
end

---@param scope? string
function Grapple.clear_cache(scope)
    local App = require("grapple.app")

    local app = App.get()

    -- TODO: This is digging a bit too far into the scope manager,
    -- but just a bit too lazy right now to fix
    app.scope_manager.cache:invalidate(scope or app.settings.scope)
end

---Clear all tags for a given scope
---By default, uses the current scope
---@param opts? { scope?: string }
function Grapple.reset(opts)
    local App = require("grapple.app")

    opts = opts or {}

    local app = App.get()
    local scope, err = app.scope_manager:get_resolved(opts.scope or app.settings.scope)
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = app.tag_manager:reset(scope.id)
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        vim.notify(err, vim.log.levels.ERROR)
    end
end

---Convenience function to open content in a new floating window
---@param content grapple.tag_content | grapple.scope_content | grapple.container_content
local function open(content)
    local App = require("grapple.app")
    local Window = require("grapple.window")

    local app = App:get()
    local window = Window:new(app.settings.win_opts)

    window:open()
    window:attach(content)

    local err = window:render()
    if err then
        vim.notify(err, vim.log.levels.ERROR)
    end
end

---Open a floating window populated with all tags for a given scope
---By default, uses the current scope
---@param scope_name? string
function Grapple.open_tags(scope_name)
    local App = require("grapple.app")
    local TagContent = require("grapple.tag_content")

    local app = App.get()
    local scope, err = app.scope_manager:get_resolved(scope_name or app.settings.scope)
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    local content = TagContent:new(scope, app.settings.tag_hook, app.settings.tag_title)

    open(content)
end

---Open a floating window populated with all defined scopes
function Grapple.open_scopes()
    local App = require("grapple.app")
    local ScopeContent = require("grapple.scope_content")

    local app = App.get()
    local content = ScopeContent:new(app.scope_manager, app.settings.scope_hook, app.settings.scope_title)

    open(content)
end

---Open a floating window populated with all loaded tag containers
function Grapple.open_containers()
    local App = require("grapple.app")
    local ContainerContent = require("grapple.container_content")

    local app = App.get()
    local content = ContainerContent:new(app.tag_manager, app.settings.container_hook, app.settings.container_title)

    open(content)
end

---Initialize Grapple. Sets up autocommands to watch tagged files and creates the
---"Grapple" user command. Called only once when plugin is loaded.
function Grapple.initialize()
    vim.api.nvim_create_augroup("Grapple", { clear = true })

    vim.api.nvim_create_autocmd({ "BufWinLeave", "QuitPre" }, {
        pattern = "?*", -- non-empty file
        group = "Grapple",
        callback = function(opts)
            local app = require("grapple.app").get()
            local buf_name = vim.api.nvim_buf_get_name(opts.buf)
            app.tag_manager:update_all({ path = buf_name })
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

                if value == "" then
                    value = nil
                end

                if not key then
                    table.insert(args, tonumber(arg) or arg)
                else
                    kwargs[key] = tonumber(value) or value
                end
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
            complete = function(current, command, index)
                -- TODO: implement command completion
                -- "current" gives the current argument the user is writing (can be partial)
                -- "command" gives the entire command line
                -- "index" gives the cursor location
            end,
        }
    )
end

return Grapple
