local ResolvedScope = require("grapple.resolved_scope")

---@class grapple.scope
---@field name string
---@field desc string
---@field resolver grapple.scope_resolver
---@field fallback grapple.scope | nil
local Scope = {}
Scope.__index = Scope

---@alias grapple.scope_resolver fun(): string?, string?, string? (id, path, error)

---@param name string
---@param resolver grapple.scope_resolver
---@param opts? { desc?: string, fallback?: grapple.scope }
---@return grapple.scope
function Scope:new(name, resolver, opts)
    opts = opts or {}

    return setmetatable({
        name = name,
        desc = opts.desc,
        resolver = resolver,
        fallback = opts.fallback,
    }, self)
end

---@param tag_manager grapple.tag_manager
---@return grapple.resolved_scope | nil, string? error
function Scope:resolve(tag_manager)
    local id, path, err = self.resolver()

    if not id then
        if self.fallback then
            return self.fallback:resolve(tag_manager)
        else
            return nil, err
        end
    end

    return ResolvedScope:new(self.name, id, path, tag_manager), nil
end

return Scope
