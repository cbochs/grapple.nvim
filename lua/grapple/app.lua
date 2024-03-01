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

---@param scope_name? string
---@param callback fun(container: grapple.tag_container): string?
---@param opts { sync: boolean }
function App:enter(scope_name, callback, opts)
    local scope, err = self.scope_manager:get_resolved(scope_name or self.settings.scope)
    if not scope then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = scope:enter(callback, opts)
    if err then
        vim.notify(err, vim.log.levels.WARN)
    end
end

---@return grapple.resolved_scope | nil, string? error
---@param callback fun(container: grapple.tag_container): string?
function App:enter_with_save(scope_name, callback)
    self:enter(scope_name, callback, { sync = true })
end

---@return grapple.resolved_scope | nil, string? error
---@param callback fun(container: grapple.tag_container): string?
function App:enter_without_save(scope_name, callback)
    self:enter(scope_name, callback, { sync = false })
end

return App
