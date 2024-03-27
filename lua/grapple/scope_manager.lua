local ResolvedScope = require("grapple.resolved_scope")
local Scope = require("grapple.scope")

---@class grapple.scope_manager
---@field app grapple.app
---@field cache grapple.cache
---@field scopes table<string, grapple.scope>
---@field resolved_lookup table<string, grapple.resolved_scope>
local ScopeManager = {}
ScopeManager.__index = ScopeManager

---@param app grapple.app
---@param cache grapple.cache
---@return grapple.scope_manager
function ScopeManager:new(app, cache)
    return setmetatable({
        app = app,
        cache = cache,
        scopes = {},
        resolved_lookup = {},
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

    local cached = self.cache:get(name)
    if cached then
        return cached, nil
    end

    ---@diagnostic disable-next-line: redefined-local
    local resolved, err = scope:resolve()
    if not resolved then
        return nil, err
    end

    self.cache:store(name, resolved)
    self.resolved_lookup[resolved.id] = resolved

    return resolved
end

---@param id string
---@return grapple.resolved_scope | nil, string? error
function ScopeManager:lookup(id)
    local resolved = self.resolved_lookup[id]

    if resolved then
        return resolved, nil
    end

    ---@param item grapple.tag_container_item
    ---@return string id
    local to_id = function(item)
        return item.id
    end

    -- TODO: This lookup is using the tag_manager. Maybe it should be moved
    -- somewhere else? Looks like an opportunity for refactoring
    local ids = vim.tbl_map(to_id, self.app.tag_manager:list())
    if vim.tbl_contains(ids, id) then
        return ResolvedScope:new(self.app, "unknown", id, nil), nil
    end

    return nil, string.format("could not find resolved scope for id: %s", id)
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
        ---@diagnostic disable-next-line: param-type-mismatch
        self.cache:open(name, opts.cache == true and {} or opts.cache)
    end

    local scope = Scope:new(self.app, name, resolver, {
        desc = opts.desc,
        fallback = fallback,
        hidden = opts.hidden,
    })

    self.scopes[name] = scope

    return nil
end

---@param name string
---@return string? error
function ScopeManager:delete(name)
    if not self:exists(name) then
        return
    end

    self.cache:close(name)
    self.scopes[name] = nil
end

return ScopeManager
