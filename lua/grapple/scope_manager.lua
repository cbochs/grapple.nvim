local Scope = require("grapple.scope")
local Util = require("grapple.util")

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

---@return boolean
function ScopeManager:exists(name)
    return self.scopes[name] ~= nil
end

---@return grapple.scope[]
function ScopeManager:list()
    ---@param scope_a grapple.scope
    ---@param scope_b grapple.scope
    local function by_name(scope_a, scope_b)
        return string.lower(scope_a.name) < string.lower(scope_b.name)
    end

    return Util.sort(vim.tbl_values(self.scopes), by_name)
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

---@param definition grapple.scope_definition
---@return string? error
function ScopeManager:define(definition)
    vim.validate({
        name = { definition.name, "string" },
        resolver = { definition.resolver, "function" },
    })

    if self:exists(definition.name) then
        if not definition.force then
            return string.format("scope already exists: %s", definition.name)
        end

        self.cache:close(definition.name)
    end

    local fallback, err
    if definition.fallback then
        fallback, err = self:get(definition.fallback)
        if not fallback then
            return string.format("could not create scope: %s, error: %s", definition.name, err)
        end
    end

    if definition.cache then
        definition.cache = definition.cache == true and {} or definition.cache
        self.cache:open(definition.name, definition.cache --[[ @as grapple.cache.options ]])
    end

    local scope = Scope:new(definition.name, definition.resolver, {
        desc = definition.desc,
        fallback = fallback,
        hidden = definition.hidden,
    })

    self.scopes[definition.name] = scope

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
