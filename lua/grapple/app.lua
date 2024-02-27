---@class grapple.app
---@field settings grapple.settings
---@field scope_manager grapple.scope.manager
---@field tag_manager grapple.tag.manager
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
    local StateManager = require("grapple.state_manager")
    local TagManager = require("grapple.tag_manager")

    local settings = Settings:new()

    local state_manager = StateManager:new(settings.save_path)
    local tag_manager = TagManager:new(state_manager)

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

    for _, scope_definition in ipairs(self.settings.scopes) do
        self.scope_manager:define(scope_definition.name, scope_definition.resolver, {
            force = true,
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

---@return grapple.scope.resolved | nil, string? error
function App:current_scope()
    return self.scope_manager:get_resolved(self.settings.scope)
end

return App
