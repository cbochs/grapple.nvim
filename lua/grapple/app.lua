local Cache = require("grapple.cache")
local ContainerContent = require("grapple.container_content")
local ScopeContent = require("grapple.scope_content")
local ScopeManager = require("grapple.scope_manager")
local Settings = require("grapple.settings")
local State = require("grapple.state")
local TagContent = require("grapple.tag_content")
local TagManager = require("grapple.tag_manager")
local Window = require("grapple.window")

---@class grapple.app
---@field settings grapple.settings
---@field cache grapple.cache
---@field scope_manager grapple.scope_manager
---@field tag_manager grapple.tag_manager
local App = {}
App.__index = App

---A global instance of the Grapple app
---@type grapple.app
local app

---@return grapple.app
function App.get()
    if app then
        return app
    end

    app = App:new()
    app:update()

    return app
end

---@return grapple.app
function App:new()
    local settings = Settings:new()

    local app = setmetatable({
        settings = settings,
        cache = Cache:new(),
        scope_manager = nil,
        tag_manager = nil,
    }, self)

    -- TODO: I think the "scope" cache and "glboal" cache should be separate.
    -- Think about this more and decided on the best approach. Note: right now
    -- the scope manager only really needs the "app" to get the tag_manager for
    -- a single method. A bit of refactoring could probably remove this
    -- dependency
    local cache = Cache:new()
    local scope_manager = ScopeManager:new(app, cache)

    local state = State:new(settings.save_path)
    local tag_manager = TagManager:new(app, state)

    app.scope_manager = scope_manager
    app.tag_manager = tag_manager

    return app
end

---@param opts? grapple.settings
---@return string? error
function App:update(opts)
    self.settings:update(opts)

    for _, definition in ipairs(self.settings:scopes()) do
        if definition.delete then
            self:delete_scope(definition.name)
        else
            local err = self:define_scope(vim.tbl_extend("force", definition, { force = true }))
            if err then
                return err
            end
        end
    end
end

---@class grapple.options
---@field buffer? integer
---@field path? string
---@field name? string
---@field index? integer
---@field cursor? integer[]
---@field scope? string
---@field command? fun(path: string)

---Extract a valid path from the provided path or buffer options.
---@param opts grapple.options
---@return string | nil path, string? error
function App:extract_path(opts)
    -- Special case: get the path under the cursor
    if opts.path and opts.path == "<cfile>" then
        return vim.fn.expand("<cfile>")
    end

    if opts.path then
        return opts.path
    end

    local buffer = opts.buffer or 0

    if not vim.api.nvim_buf_is_valid(buffer) then
        return nil, string.format("invalid buffer: %s", buffer)
    end

    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buffer })
    if vim.tbl_contains(self.settings.exclusions.buftype, buftype) then
        return nil, string.format("invalid buftype for buffer %s: %s", buffer, buftype)
    end

    local filetype = vim.api.nvim_get_option_value("filetype", { buf = buffer })
    if vim.tbl_contains(self.settings.exclusions.filetype, filetype) then
        return nil, string.format("invalid filetype for buffer %s: %s", buffer, filetype)
    end

    local bufname = vim.api.nvim_buf_get_name(buffer)
    if vim.tbl_contains(self.settings.exclusions.name, bufname) then
        return nil, string.format('invalid name for buffer %s: "%s"', buffer, bufname)
    end

    return vim.api.nvim_buf_get_name(buffer), nil
end

---Create a new tag or update an existing tag on a path, URI, or buffer
---By default, uses the current scope
---@param opts? grapple.options
---@return string? error
function App:tag(opts)
    opts = opts or {}
    return self:enter_with_save(opts.scope, function(container)
        local path, err = self:extract_path(opts)
        if err or not path then
            return err
        end
        opts.path = path

        return container:insert(opts)
    end)
end

---Delete a tag on a path, URI, or buffer
---By default, uses the current scope
---@param opts? grapple.options
---@return string? error
function App:untag(opts)
    opts = opts or {}
    return self:enter_with_save(opts.scope, function(container)
        local path, err = self:extract_path(opts)
        if err or not path then
            return err
        end
        opts.path = path

        return container:remove(opts)
    end)
end

---Toggle a tag on a path, URI, or buffer. Lookup is done by index, name, path, or buffer
---By default, uses the current scope
---@param opts? grapple.options
---@return string? error
function App:toggle(opts)
    opts = opts or {}
    return self:enter_with_save(opts.scope, function(container)
        local path, err = self:extract_path(opts)
        if err or not path then
            return err
        end
        opts.path = path

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
---@return string? error
function App:select(opts)
    opts = opts or {}
    self:enter_without_save(opts.scope, function(container)
        local path, _ = self:extract_path(opts)
        opts.path = path

        local index, err = container:find(opts)
        if err or not index then
            return err
        end

        local tag = assert(container:get({ index = index }))

        tag:select(opts.command)
    end)
end

---@param current_index? integer
---@param direction "next" | "prev"
---@param length integer
---@return integer
local function next_index(current_index, direction, length)
    -- Fancy maths to get the next index for a given direction
    -- 1. Change to 0-based indexing
    -- 2. Perform index % container length, being careful of negative values
    -- 3. Change back to 1-based indexing
    -- stylua: ignore
    current_index = (
        current_index
        or direction == "next" and length
        or direction == "prev" and 1
    ) - 1

    local next_inc = direction == "next" and 1 or -1
    local next_idx = math.fmod(current_index + next_inc + length, length) + 1

    return next_idx
end

-- Cycle through and select the next or previous available tag for a given scope.
---By default, uses the current scope
---@param direction "next" | "prev" | "previous" | "forward" | "backward"
---@param opts? grapple.options
---@return string? error
function App:cycle_tags(direction, opts)
    opts = opts or {}

    -- stylua: ignore
    direction = direction == "forward" and "next"
        or direction == "backward" and "prev"
        or direction == "previous" and "prev"
        or direction

    ---@cast direction "next" | "prev"

    if not vim.tbl_contains({ "next", "prev" }, direction) then
        return vim.notify(string.format("invalid direction: %s", direction), vim.log.levels.ERROR)
    end

    return self:enter_without_save(opts.scope, function(container)
        if container:is_empty() then
            return
        end

        local path, _ = self:extract_path(opts)
        opts.path = path

        local index = next_index(container:find(opts), direction, container:len())

        local tag, err = container:get({ index = index })
        if err or not tag then
            return err
        end

        ---@diagnostic disable-next-line: redefined-local
        local err = tag:select()
        if err then
            return err
        end
    end)
end

---Search for a tag in a given scope
---@param opts? grapple.options
---@return grapple.tag | nil, string? error
function App:find(opts)
    opts = opts or {}

    ---@type grapple.tag | nil
    local tag

    local err = self:enter_without_save(opts.scope, function(container)
        local path, _ = self:extract_path(opts)
        opts.path = path

        local index, err = container:find(opts)
        if err or not index then
            return err
        end

        tag = assert(container:get({ index = index }))
    end, { notify = false })

    if err then
        return nil, err
    end

    return tag, nil
end

---Return the name or index of a tag. Used for statusline components
---@param opts? grapple.options
---@return string | integer | nil
function App:name_or_index(opts)
    opts = opts or {}

    ---@type string | integer | nil
    local name_or_index

    self:enter_without_save(opts.scope, function(container)
        local path, _ = self:extract_path(opts)
        opts.path = path

        local tag = container:get(opts)
        if tag then
            name_or_index = tag.name or assert(container:find(opts))
        end
    end)

    return name_or_index
end

---Return the tags for a given scope. Used for integrations
---@param opts? { scope?: string }
---@return grapple.tag[] | nil, string? error
function App:tags(opts)
    opts = opts or {}

    local scope, err = self.scope_manager:get_resolved(opts.scope or self.settings.scope)
    if err or not scope then
        return nil, err
    end

    ---@diagnostic disable-next-line: redefined-local
    local tags, err = scope:tags()
    if err or not tags then
        return nil, err
    end

    return vim.deepcopy(tags), nil
end

---Return a formatted string to be displayed on the statusline
---@param definition grapple.scope_definition
---@return string? error
function App:define_scope(definition)
    return self.scope_manager:define(definition.name, definition.resolver, {
        force = definition.force,
        desc = definition.desc,
        fallback = definition.fallback,
        cache = definition.cache,
        hidden = definition.hidden,
    })
end

---@param scope_name string
---@return string? error
function App:delete_scope(scope_name)
    return self.scope_manager:delete(scope_name)
end

---Change the currently selected scope
---@param scope_name string
---@return string? error
function App:use_scope(scope_name)
    local scope, err = self.scope_manager:get(scope_name)
    if err or not scope then
        return err
    end

    if scope.name ~= self.settings.scope then
        self.settings:update({ scope = scope.name })

        vim.api.nvim_exec_autocmds("User", {
            pattern = "GrappleScopeChanged",
            modeline = false,
        })
    end
end

---Unload tags for a given scope (name) or loaded scope (id)
---By default, uses the current scope
---@param opts? { scope?: string, id?: string }
---@return string? error
function App:unload_scope(opts)
    local id, name, err = self:resolve_scope(opts)
    if not id then
        return err
    end

    if name then
        self.scope_manager.cache:unwatch(name)
    end

    self.tag_manager:unload(id)
end

---Reset tags for a given scope (name) or loaded scope (id)
---By default, uses the current scope
---@param opts? { scope?: string, id?: string }
---@return string? error
function App:reset_scope(opts)
    local id, name, err = self:resolve_scope(opts)
    if not id then
        return err
    end

    if name then
        self.scope_manager.cache:unwatch(name)
    end

    self.tag_manager:reset(id)
end

---@return grapple.resolved_scope | nil, string? error
function App:current_scope()
    return self.scope_manager:get_resolved(self.settings.scope)
end

---@param opts? { scope?: string, id?: string }
---@return string | nil id, string | nil name, string? error
function App:resolve_scope(opts)
    opts = vim.tbl_extend("keep", opts or {}, {
        scope = self.settings.scope,
    })

    -- The loaded scope's ID and associated scope's name
    ---@type string, string | nil
    local id, name

    if opts.id then
        -- Case: reset by id: scope may be or may not be loaded
        local scope, _ = self.scope_manager:lookup(opts.id)

        id = opts.id
        name = scope and scope.name
    elseif opts.scope then
        -- Case: reset by name: scope id and name must be available
        local scope, err = self.scope_manager:get_resolved(opts.scope)
        if not scope then
            ---@diagnostic disable-next-line: param-type-mismatch
            return nil, nil, err
        end

        id = scope.id
        name = scope.name
    end

    if not id then
        return nil, nil, string.format("must provide a valid scope or id: %s", vim.inspect(opts))
    end

    return id, name, nil
end

---Convenience function to open content in a new floating window
---@param content grapple.tag_content | grapple.scope_content | grapple.container_content
---@return string? error
function App:open_window(content)
    local window = Window:new(self.settings.win_opts)

    window:open()
    window:attach(content)

    return window:render()
end

---Open a floating window populated with all tags for a given (scope) name
---or loaded scope (id). By default, uses the current scope
---@param opts? { scope?: string, id?: string, style?: string }
---@return string? error
function App:open_tags(opts)
    opts = opts or {}

    local scope, err
    if opts.id then
        scope, err = self.scope_manager:lookup(opts.id)
    else
        scope, err = self.scope_manager:get_resolved(opts.scope or self.settings.scope)
    end

    if err or not scope then
        return err
    end

    -- stylua: ignore
    local content = TagContent:new(
        scope,
        self.settings.tag_hook,
        self.settings.tag_title,
        self.settings.styles[opts.style or self.settings.style]
    )

    return self:open_window(content)
end

---Open a floating window populated with all defined scopes
---@param opts? { all: boolean }
---@return string? error
function App:open_scopes(opts)
    local show_all = opts and opts.all or false
    local content = ScopeContent:new(self, self.settings.scope_hook, self.settings.scope_title, show_all)

    return self:open_window(content)
end

---Open a floating window populated with all loaded scopes
---@param opts? { all: boolean }
---@return string? error
function App:open_loaded(opts)
    local show_all = opts and opts.all or false
    local content = ContainerContent:new(self, self.settings.loaded_hook, self.settings.loaded_title, show_all)

    return self:open_window(content)
end

---@param scope_name? string
---@param callback fun(container: grapple.tag_container): string? error
---@param opts { sync?: boolean, notify?: boolean }
---@return string? error
function App:enter(scope_name, callback, opts)
    opts = vim.tbl_extend("keep", opts or {}, {
        sync = true,
        notify = true,
    })

    local scope, err = self.scope_manager:get_resolved(scope_name or self.settings.scope)
    if not scope then
        if opts.notify then
            ---@diagnostic disable-next-line: param-type-mismatch
            vim.notify(err, vim.log.levels.ERROR)
        end
        return err
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = scope:enter(callback, { sync = opts.sync })
    if err then
        if opts.notify then
            vim.notify(err, vim.log.levels.WARN)
        end
        return err
    end

    return nil
end

---@param scope_name? string
---@param callback fun(container: grapple.tag_container): string? error
---@param opts? { notify?: boolean }
---@return string? error
function App:enter_with_save(scope_name, callback, opts)
    return self:enter(scope_name, callback, { sync = true, notify = opts and opts.notify })
end

---@param scope_name? string
---@param callback fun(container: grapple.tag_container): string? error
---@param opts? { notify?: boolean }
---@return string? error
function App:enter_without_save(scope_name, callback, opts)
    return self:enter(scope_name, callback, { sync = false, notify = opts and opts.notify })
end

return App
