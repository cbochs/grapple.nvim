local Scope = require("grapple.scope")

---@class grapple.scope_manager
---@field cache grapple.cache
---@field scopes table<string, grapple.scope>
local ScopeManager = {}
ScopeManager.__index = ScopeManager

---@param cache grapple.cache
---@return grapple.scope_manager
function ScopeManager:new(cache)
    return setmetatable({
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
        return nil, string.format("could not find scope: %s", name)
    end

    return self.scopes[name], nil
end

---@param name string scope name
---@return grapple.resolved_scope | nil, string? error
function ScopeManager:get_resolved(name)
    local scope, err = self:get(name)
    if not scope then
        return nil, err
    end

    -- Check the cache first
    local resolved = self.cache:get(name)
    if resolved then
        return resolved, nil
    end

    -- Cache missed, must resolve
    ---@diagnostic disable-next-line: redefined-local
    local resolved, err = scope:resolve()
    if not resolved then
        return nil, err
    end

    self.cache:store(name, resolved)

    return resolved
end

---@param name string
---@param resolver grapple.scope_resolver
---@param opts? { force?: boolean, desc?: string, fallback?: string, cache?: grapple.cache.options | boolean, hidden?: boolean }
---@return string? error
function ScopeManager:define(name, resolver, opts)
    opts = opts or {}

    if self:exists(name) then
        if not opts.force then
            return string.format("scope already exists: %s", name)
        end

        self.cache:close(name)
    end

    local fallback, err
    if opts.fallback then
        fallback, err = self:get(opts.fallback)
        if not fallback then
            return string.format("could not create scope: %s, error: %s", name, err)
        end
    end

    if opts.cache then
        opts.cache = opts.cache == true and {} or opts.cache
        self.cache:open(name, opts.cache --[[ @as grapple.cache.options ]])
    end

    local scope = Scope:new(name, resolver, {
        desc = opts.desc,
        fallback = fallback,
        hidden = opts.hidden,
    })

    self.scopes[name] = scope

    return nil
end

---@param name string
function ScopeManager:unload(name)
    if not self:exists(name) then
        return
    end

    self.cache:unwatch(name)
end

---@param name string
function ScopeManager:delete(name)
    if not self:exists(name) then
        return
    end

    self.cache:close(name)
    self.scopes[name] = nil
end

return ScopeManager
