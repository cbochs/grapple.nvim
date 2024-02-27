local ResolvedScope = require("grapple.resolved_scope")

---@class grapple.scope
---@field name string
---@field resolver grapple.scope_resolver
---@field fallback grapple.scope | nil
local Scope = {}
Scope.__index = Scope

---A resolving function which returns a tuple of (id, path?, error?)
---@alias grapple.scope_resolver fun(): string?, string?, string?

---@param name string
---@param resolver grapple.scope_resolver
---@param fallback? grapple.scope
---@return grapple.scope
function Scope:new(name, resolver, fallback)
    return setmetatable({
        name = name,
        resolver = resolver,
        fallback = fallback,
    }, self)
end

---@param tag_manager grapple.tag.manager
---@return grapple.resolved_scope | nil, string? error
function Scope:resolve(tag_manager)
    local id, path, err = self.resolver()

    if not id then
        if self.fallback then
            vim.print(string.format("GOING UP FROM %s TO %s", self.name, self.fallback.name))
            return self.fallback:resolve(tag_manager)
        end

        return nil, err
    end

    return ResolvedScope:new(self.name, id, path, tag_manager), nil
end

return Scope
