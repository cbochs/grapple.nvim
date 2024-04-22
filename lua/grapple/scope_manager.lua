local Scope = require("grapple.scope")

---@class grapple.scope_manager
---@field scopes table<string, grapple.scope>
local ScopeManager = {}
ScopeManager.__index = ScopeManager

---@return grapple.scope_manager
function ScopeManager:new()
    return setmetatable({
        scopes = {},
    }, self)
end

function ScopeManager:exists(name)
    return name ~= nil and self.scopes[name] ~= nil
end

---@param name string scope name
---@return grapple.scope | nil, string? error
function ScopeManager:get(name)
    if not self:exists(name) then
        return nil, string.format("could not find scope: %s", name)
    end

    return self.scopes[name], nil
end

---@param context grapple.context
---@param name string scope name
---@return grapple.resolved_scope | nil, string? error
function ScopeManager:get_resolved(context, name)
    local scope, err = self:get(name)
    if not scope then
        return nil, err
    end

    -- Check the cache first
    local resolved = context.cache:get(name)
    if resolved then
        if not context.cache:is_open(resolved.id) then
            context.cache:open(resolved.id, {})
        end
        context.cache:store(resolved.id, resolved)

        return resolved, nil
    end

    ---@diagnostic disable-next-line: redefined-local
    local resolved, err = scope:resolve()
    if not resolved then
        return nil, err
    end

    context.cache:store(name, resolved)

    if not context.cache:is_open(resolved.id) then
        context.cache:open(resolved.id, {})
    end
    context.cache:store(resolved.id, resolved)

    return resolved
end

function ScopeManager:get_resolved_by_id(context, id)
    return context.cache:get(id)
end

---@param context grapple.context
---@param name string
---@param resolver grapple.scope_resolver
---@param opts? { force?: boolean, desc?: string, fallback?: string, cache?: grapple.cache.options | boolean, hidden?: boolean }
---@return string? error
function ScopeManager:define(context, name, resolver, opts)
    opts = opts or {}

    if self:exists(name) then
        if not opts.force then
            return string.format("scope already exists: %s", name)
        end

        context.cache:close(name)
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
        context.cache:open(name, opts.cache --[[ @as grapple.cache.options ]])
    end

    local scope = Scope:new(name, resolver, {
        desc = opts.desc,
        fallback = fallback,
        hidden = opts.hidden,
    })

    self.scopes[name] = scope

    return nil
end

---@param context grapple.context
---@param name string
---@return string? error
function ScopeManager:delete(context, name)
    if not self:exists(name) then
        return
    end

    context.cache:close(name)

    self.scopes[name] = nil
end

---@param context grapple.context
---@param name string
function ScopeManager:unload(context, name)
    if not self:exists(name) then
        return
    end

    context.cache:unwatch(name)
end

return ScopeManager
