local ResolvedScope = require("grapple.resolved_scope")

---@class grapple.scope
---@field name string
---@field resolver grapple.scope.resolver
---@field persisted boolean
local Scope = {}
Scope.__index = Scope

---@alias grapple.scope.id string
---@alias grapple.scope.path string
---@alias grapple.scope.resolver fun(): grapple.scope.id, grapple.scope.path | nil, string?

---@param name string
---@param resolver grapple.scope.resolver
---@param persisted boolean
---@return grapple.scope
function Scope:new(name, resolver, persisted)
    return setmetatable({
        name = name,
        resolver = resolver,
        persisted = persisted,
    }, self)
end

---@param tag_manager grapple.tag.manager
---@return grapple.scope.resolved, string? error
function Scope:resolve(tag_manager)
    local id, path, err = self.resolver()
    if err then
        return {}, err
    end

    return ResolvedScope:new(id, path, self.persisted, tag_manager), nil
end

return Scope
