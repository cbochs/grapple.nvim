local Scope = require("grapple.scope")

---@class grapple.scope.manager
---@field tag_manager grapple.tag.manager
---@field scopes table<string, grapple.scope>
local ScopeManager = {}
ScopeManager.__index = ScopeManager

---@param tag_manager grapple.tag.manager
---@return grapple.scope.manager
function ScopeManager:new(tag_manager)
    return setmetatable({
        tag_manager = tag_manager,
        scopes = {},
    }, self)
end

function ScopeManager:exists(name)
    return self.scopes[name] ~= nil
end

---@param name string scope name
---@return grapple.scope | nil, string? error
function ScopeManager:get(name)
    if not self:exists(name) then
        return nil, string.format("Could not find scope %s", name)
    end

    return self.scopes[name], nil
end

---@param name string scope name
---@return grapple.scope.resolved | nil, string? error
function ScopeManager:get_resolved(name)
    local scope, err = self:get(name)
    if not scope then
        return nil, err
    end

    return scope:resolve(self.tag_manager)
end

---@param name string
---@param resolver grapple.scope.resolver
---@param opts? { fallback?: string, force?: boolean }
---@return grapple.scope | nil, string? error
function ScopeManager:define(name, resolver, opts)
    if self:exists(name) and not (opts and opts.force) then
        return nil, string.format("scope already exists: %s", name)
    end

    local fallback, err
    if opts and opts.fallback then
        fallback, err = self:get(opts.fallback)
        if not fallback then
            return nil, err
        end
    end

    local scope = Scope:new(name, resolver, fallback)
    self.scopes[name] = scope

    return scope, nil
end

return ScopeManager
