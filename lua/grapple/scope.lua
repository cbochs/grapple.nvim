local ResolvedScope = require("grapple.resolved_scope")

---@class grapple.scope
---@field app grapple.app
---@field name string
---@field desc string
---@field resolver grapple.scope_resolver
---@field fallback grapple.scope | nil
---@field hidden boolean
local Scope = {}
Scope.__index = Scope

---@alias grapple.scope_resolver fun(): string?, string?, string? (id, path, error)

---@param app grapple.app
---@param name string
---@param resolver grapple.scope_resolver
---@param opts? { desc?: string, fallback?: grapple.scope, hidden?: boolean }
---@return grapple.scope
function Scope:new(app, name, resolver, opts)
    opts = opts or {}

    return setmetatable({
        app = app,
        name = name,
        desc = opts.desc or "",
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

    return ResolvedScope:new(self.app, self.name, id, path), nil
end

return Scope
