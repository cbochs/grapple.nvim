---@class grapple.app
---@field settings grapple.settings
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
    local Cache = require("grapple.cache")
    local ScopeManager = require("grapple.scope_manager")
    local Settings = require("grapple.settings")
    local State = require("grapple.state")
    local TagManager = require("grapple.tag_manager")

    local settings = Settings:new()

    local state = State:new(settings.save_path)
    local tag_manager = TagManager:new(state)

    local cache = Cache:new()
    local scope_manager = ScopeManager:new(tag_manager, cache)

    return setmetatable({
        settings = settings,
        scope_manager = scope_manager,
        tag_manager = tag_manager,
    }, self)
end

---@param opts? grapple.settings
function App:update(opts)
    self.settings:update(opts)

    -- Define default scopes, if not already defined
    for _, definition in ipairs(self.settings.default_scopes) do
        self:define_scope(vim.tbl_extend("force", definition, { force = false }))
    end

    -- Define user scopes, force recreation
    for _, definition in ipairs(self.settings.scopes) do
        self:define_scope(vim.tbl_extend("force", definition, { force = true }))
    end
end

---@param definition grapple.scope_definition
function App:define_scope(definition)
    self.scope_manager:define(definition.name, definition.resolver, {
        force = definition.force,
        desc = definition.desc,
        fallback = definition.fallback,
        cache = definition.cache,
    })
end

---@return string? error
function App:load_current_scope()
    local scope, err = self:current_scope()
    if not scope then
        return err
    end

    self.tag_manager:load(scope.id)
end

---@return grapple.resolved_scope | nil, string? error
function App:current_scope()
    return self.scope_manager:get_resolved(self.settings.scope)
end

---Reset tags for a given scope (name) or loaded scope (id)
---By default, uses the current scope
---@param opts? { scope?: string, id?: string }
---@return string? error
function App:reset(opts)
    opts = vim.tbl_extend("keep", opts or {}, {
        scope = self.settings.scope,
    })

    -- The loaded scope's ID and associated scope's name
    ---@type string
    local id, name

    if opts.id then
        local scope, err = app.scope_manager:lookup(opts.id)
        if not scope then
            ---@diagnostic disable-next-line: param-type-mismatch
            return err
        end

        id = opts.id
        name = scope.name
    elseif opts.scope then
        local scope, err = app.scope_manager:get_resolved(opts.scope)
        if not scope then
            return err
        end

        id = scope.id
        name = scope.name
    end

    if not id or not name then
        return string.format("must provide a valid scope or id: %s", vim.inspect(opts))
    end

    self.scope_manager.cache:unwatch(name)

    ---@diagnostic disable-next-line: redefined-local
    local err = self.tag_manager:reset(id)
    if err then
        return err
    end
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
