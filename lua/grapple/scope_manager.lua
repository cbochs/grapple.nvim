local Scope = require("grapple.scope")

---@class grapple.scope.manager
---@field tag_manager grapple.tag.manager
---@field cache grapple.cache
---@field scopes table<string, grapple.scope>
local ScopeManager = {}
ScopeManager.__index = ScopeManager

---@param tag_manager grapple.tag.manager
---@param cache grapple.cache
---@return grapple.scope.manager
function ScopeManager:new(tag_manager, cache)
    return setmetatable({
        tag_manager = tag_manager,
        cache = cache,
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

    local cached = self.cache:get(name)
    if cached then
        return cached, nil
    end

    ---@diagnostic disable-next-line: redefined-local
    local resolved, err = scope:resolve(self.tag_manager)
    if not resolved then
        return nil, err
    end

    self.cache:store(name, resolved)

    return resolved
end

---@param name string
---@param resolver grapple.scope.resolver
---@param opts? { force?: boolean, fallback?: string, cache?: grapple.cache.opts }
---@return grapple.scope | nil, string? error
function ScopeManager:define(name, resolver, opts)
    opts = opts or {}

    if self:exists(name) and not opts.force then
        return nil, string.format("scope already exists: %s", name)
    end

    local fallback, err
    if opts.fallback then
        fallback, err = self:get(opts.fallback)
        if not fallback then
            return nil, err
        end
    end

    if opts.cache then
        self.cache:open(name, opts.cache)
    end

    local scope = Scope:new(name, resolver, fallback)
    self.scopes[name] = scope

    return scope, nil
end

return ScopeManager
