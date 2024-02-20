local ResolvedScope = require("grapple.new.resolved_scope")

---@class Scope
---@field name string
---@field resolver Resolver
---@field persisted boolean
local Scope = {}
Scope.__index = Scope

---@alias Id string
---@alias Path string
---@alias Resolver fun(): Id, Path | nil, string?

---@param name string
---@param resolver Resolver
---@param persisted boolean
---@return Scope
function Scope:new(name, resolver, persisted)
    return setmetatable({
        name = name,
        resolver = resolver,
        persisted = persisted,
    }, self)
end

---@param tag_manager TagManager
---@return ResolvedScope, string? error
function Scope:resolve(tag_manager)
    local id, path, err = self.resolver()
    if err then
        return {}, err
    end

    return ResolvedScope:new(id, path, self.persisted, tag_manager), nil
end

return Scope
