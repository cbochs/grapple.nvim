local ResolvedScope = require("grapple.resolved_scope")

---@class grapple.scope
---@field name string
---@field desc string
---@field resolver grapple.scope_resolver
---@field fallback grapple.scope | nil
---@field hidden boolean
local Scope = {}
Scope.__index = Scope

---@alias grapple.scope_resolver fun(): string?, string?, string? (id, path, error)

---@param name string
---@param resolver grapple.scope_resolver
---@param opts? { desc?: string, fallback?: grapple.scope, hidden?: boolean }
---@return grapple.scope
function Scope:new(name, resolver, opts)
    opts = opts or {}

    return setmetatable({
        name = name,
        desc = opts.desc,
        resolver = resolver,
        fallback = opts.fallback,
        hidden = opts.hidden,
    }, self)
end

---Implements Resolvable
---@return grapple.resolved_scope | nil, string? error
function Scope:resolve()
    local id, path, err = self.resolver()

    if not id then
        if self.fallback then
            return self.fallback:resolve()
        end

        return nil, err
    end

    return ResolvedScope:new(self.name, id, path), nil
end

return Scope
