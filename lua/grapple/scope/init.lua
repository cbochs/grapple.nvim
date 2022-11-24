local log = require("grapple.log")

local M = {}

---@class Grapple.ScopeOptions
---@field key string
---@field cache boolean | string | string[]

---@alias Grapple.ScopeKey string | integer

---@alias Grapple.ScopePath string

---@alias Grapple.ScopeFunction fun(): Grapple.ScopePath | nil

---@class Grapple.ScopeResolver
---@field key Grapple.ScopeKey
---@field resolve Grapple.ScopeFunction
---@field cache boolean | string | string[]
---@field autocmd number | nil

---@alias Grapple.Scope Grapple.ScopePath | Grapple.ScopeKey | Grapple.ScopeResolver

---@type table<Grapple.ScopeKey, Grapple.ScopePath>
local cached_paths = {}

---@type table<Grapple.ScopeKey, Grapple.ScopeResolver>
M.resolvers = {}

---@param scope Grapple.Scope
---@return boolean
local function is_scope_path(scope)
    return vim.tbl_contains(vim.tbl_values(cached_paths), scope)
end

---@param scope Grapple.Scope
---@return boolean
local function is_scope_key(scope)
    return M.resolvers[scope] ~= nil
end

---@param scope Grapple.Scope
---@return boolean
local function is_scope_resolver(scope)
    return type(scope) == "table" and type(scope.resolve) == "function" and scope.key ~= nil
end

---@param scope Grapple.ScopeKey | Grapple.ScopeResolver
---@return Grapple.ScopeResolver
local function find_resolver(scope)
    if is_scope_key(scope) then
        return M.resolvers[scope]
    end
    if is_scope_resolver(scope) then
        return scope
    end
    log.error("Unable to find scope resolver. Scope: " .. tostring(scope))
    error("Unable to find scope resolver. Scope: " .. tostring(scope))
end

---@param scope_resolver Grapple.ScopeKey | Grapple.ScopeResolver
---@return Grapple.ScopeResolver
local function update_autocmd(scope_resolver)
    scope_resolver = find_resolver(scope_resolver)
    if type(scope_resolver.cache) == "boolean" or scope_resolver.autocmd ~= nil then
        return scope_resolver
    end

    local group = vim.api.nvim_create_augroup("GrappleScope", { clear = false })
    scope_resolver.autocmd = vim.api.nvim_create_autocmd(scope_resolver.cache, {
        group = group,
        callback = function()
            M.invalidate(scope_resolver.key)
        end,
    })

    return scope_resolver
end

---@param scope_function Grapple.ScopeFunction
---@param opts? Grapple.ScopeOptions
---@return Grapple.ScopeResolver
function M.resolver(scope_function, opts)
    opts = opts or {}

    if opts.key and M.resolvers[opts.key] ~= nil then
        log.warn("Overriding existing scope resolver. Key: " .. opts.key)

        local scope_resolver = M.resolvers[opts.key]
        if scope_resolver.autocmd ~= nil then
            vim.api.nvim_del_autocmd(scope_resolver.autocmd)
        end

        M.invalidate(scope_resolver)
        M.resolvers[scope_resolver.key] = nil
    end

    local scope_key = opts.key or (#M.resolvers + 1)
    local scope_cache = opts.cache ~= nil and opts.cache or true

    ---@type Grapple.ScopeResolver
    local scope_resolver = {
        key = scope_key,
        resolve = scope_function,
        cache = scope_cache,
        autocmd = nil,
    }

    M.resolvers[scope_key] = scope_resolver

    return scope_resolver
end

---@param root_names string | string[]
---@param opts? Grapple.ScopeOptions
---@return Grapple.ScopeResolver
function M.root(root_names, opts)
    root_names = type(root_names) == "string" and { root_names } or root_names
    opts = vim.tbl_extend("force", { cache = "DirChanged" }, opts or {})

    return M.resolver(function()
        local root_files = vim.fs.find(root_names, { upward = true })
        if #root_files > 0 then
            return vim.fs.dirname(root_files[1])
        end
        return nil
    end, opts)
end

---@param ... Grapple.ScopeResolver[]
---@return Grapple.ScopeResolver
function M.fallback(...)
    local scope_resolvers = { ... }
    return M.resolver(function()
        for _, scope_resolver in ipairs(scope_resolvers) do
            local scope_path = M.get(scope_resolver)
            if scope_path ~= nil then
                return scope_path
            end
        end
    end, { cache = false })
end

---@param scope Grapple.Scope
---@return Grapple.ScopePath | nil
function M.get(scope)
    if is_scope_path(scope) then
        return scope
    end

    scope = find_resolver(scope)
    if cached_paths[scope.key] ~= nil then
        return cached_paths[scope.key]
    end

    return M.update(scope)
end

---@param scope_resolver Grapple.ScopeKey | Grapple.ScopeResolver
---@return Grapple.ScopePath | nil
function M.update(scope_resolver)
    scope_resolver = find_resolver(scope_resolver)
    scope_resolver = update_autocmd(scope_resolver)

    local scope_path = M.resolve(scope_resolver.resolve)
    if scope_resolver.cache ~= false then
        log.debug("Updating scope cache. Cache key: " .. tostring(scope_resolver.key))
        cached_paths[scope_resolver.key] = scope_path
    end

    return scope_path
end

---@param scope_function Grapple.ScopeFunction
---@return Grapple.ScopePath | nil
function M.resolve(scope_function)
    local ok, scope_path = pcall(scope_function)
    if not ok or type(scope_path) ~= "string" then
        log.warn("Unable to resolve scope. Ok: " .. tostring(ok) .. ". Result: " .. vim.inspect(scope_path))
        return nil
    end
    return scope_path
end

---@param scope_resolver Grapple.ScopeKey | Grapple.ScopeResolver
function M.invalidate(scope_resolver)
    scope_resolver = find_resolver(scope_resolver)
    log.debug("Invalidating scope cache. Cache key: " .. tostring(scope_resolver.key))
    cached_paths[scope_resolver.key] = nil
end

return M
