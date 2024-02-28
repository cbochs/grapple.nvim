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
    for _, scope_definition in ipairs(self.settings.default_scopes) do
        self.scope_manager:define(scope_definition.name, scope_definition.resolver, {
            force = false,
            desc = scope_definition.desc,
            fallback = scope_definition.fallback,
            cache = scope_definition.cache,
        })
    end

    -- Define user scopes, force recreation
    for _, scope_definition in ipairs(self.settings.scopes) do
        self.scope_manager:define(scope_definition.name, scope_definition.resolver, {
            force = true,
            desc = scope_definition.desc,
            fallback = scope_definition.fallback,
            cache = scope_definition.cache,
        })
    end
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

---@param scope_name? string
---@param callback fun(container: grapple.tag_container): string?
function App:enter(scope_name, callback)
    local scope, err = self.scope_manager:get_resolved(scope_name or self.settings.scope)
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = scope:enter(callback)
    if err then
        vim.notify(err, vim.log.levels.WARN)
    end
end

return App
