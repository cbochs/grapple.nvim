local ResolvedScope = require("grapple.resolved_scope")

---@class grapple.scope
---@field name string
---@field resolver grapple.scope.resolver
local Scope = {}
Scope.__index = Scope

---A resolving function which returns a tuple of (id, path?, error?)
---@alias grapple.scope.resolver fun(): string, string?, string?

---@param name string
---@param resolver grapple.scope.resolver
---@return grapple.scope
function Scope:new(name, resolver)
    return setmetatable({
        name = name,
        resolver = resolver,
    }, self)
end

---@param tag_manager grapple.tag.manager
---@return grapple.scope.resolved | nil, string? error
function Scope:resolve(tag_manager)
    local id, path, err = self.resolver()
    if err then
        return nil, err
    end

    return ResolvedScope:new(self.name, id, path, tag_manager), nil
end

return Scope
