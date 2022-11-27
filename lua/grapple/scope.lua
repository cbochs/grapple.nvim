local log = require("grapple.log")

local scope = {}

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

---@alias Grapple.ScopeType Grapple.ScopeKey | Grapple.ScopeResolver

---@alias Grapple.Scope Grapple.ScopePath | Grapple.ScopeType

---@type table<Grapple.ScopeKey, Grapple.ScopePath>
local cached_paths = {}

---@type table<Grapple.ScopeKey, Grapple.ScopeResolver>
scope.resolvers = {}

---@param scope_resolver Grapple.ScopeResolver
---@return Grapple.ScopeResolver
local function update_autocmd(scope_resolver)
    if type(scope_resolver.cache) == "boolean" or scope_resolver.autocmd ~= nil then
        return scope_resolver
    end

    local group = vim.api.nvim_create_augroup("GrappleScope", { clear = false })
    scope_resolver.autocmd = vim.api.nvim_create_autocmd(scope_resolver.cache, {
        group = group,
        callback = function()
            scope.invalidate(scope_resolver.key)
        end,
    })

    return scope_resolver
end

function scope.reset()
    vim.api.nvim_create_augroup("GrappleScope", { clear = true })
    scope.resolvers = {}
    cached_paths = {}
end

---@param scope_type Grapple.ScopeType
---@return Grapple.ScopeResolver
function scope.find_resolver(scope_type)
    if type(scope_type) == "string" then
        scope_type = scope.resolvers[scope_type]
        if scope_type == nil then
            log.error("Unable to find scope resolver. Scope: " .. tostring(scope_type))
            error("Unable to find scope resolver. Scope: " .. tostring(scope_type))
        end
    end
    return scope_type
end

---@param scope_function Grapple.ScopeFunction
---@param opts? Grapple.ScopeOptions
---@return Grapple.ScopeResolver
function scope.resolver(scope_function, opts)
    opts = opts or {}

    if opts.key and scope.resolvers[opts.key] ~= nil then
        log.warn("Overriding existing scope resolver. Key: " .. opts.key)

        local scope_resolver = scope.resolvers[opts.key]
        if scope_resolver.autocmd ~= nil then
            vim.api.nvim_del_autocmd(scope_resolver.autocmd)
        end

        scope.invalidate(scope_resolver)
        scope.resolvers[scope_resolver.key] = nil
    end

    local scope_key = opts.key or (#scope.resolvers + 1)

    local scope_cache = true
    if opts.cache ~= nil then
        scope_cache = opts.cache
    end

    ---@type Grapple.ScopeResolver
    local scope_resolver = {
        key = scope_key,
        resolve = scope_function,
        cache = scope_cache,
        autocmd = nil,
    }

    scope.resolvers[scope_key] = scope_resolver

    return scope_resolver
end

---@param root_names string | string[]
---@param opts? Grapple.ScopeOptions
---@return Grapple.ScopeResolver
function scope.root(root_names, opts)
    root_names = type(root_names) == "string" and { root_names } or root_names
    opts = vim.tbl_extend("force", { cache = "DirChanged" }, opts or {})

    return scope.resolver(function()
        local root_files = vim.fs.find(root_names, { upward = true })
        if #root_files > 0 then
            return vim.fs.dirname(root_files[1])
        end
        return nil
    end, opts)
end

---@param scope_resolvers Grapple.ScopeResolver[]
---@param opts? string
---@return Grapple.ScopeResolver
function scope.fallback(scope_resolvers, opts)
    return scope.resolver(function()
        for _, scope_resolver in ipairs(scope_resolvers) do
            local scope_path = scope.get(scope_resolver)
            if scope_path ~= nil then
                return scope_path
            end
        end
    end, vim.tbl_extend("force", { cache = false }, opts or {}))
end

---@param scope_type Grapple.ScopeType
---@return Grapple.ScopePath | nil
function scope.get(scope_type)
    local scope_resolver = scope.find_resolver(scope_type)
    if cached_paths[scope_resolver.key] ~= nil then
        return cached_paths[scope_resolver.key]
    end
    return scope.update(scope_resolver)
end

---@param scope_resolver Grapple.ScopeKey | Grapple.ScopeResolver
---@return Grapple.ScopePath | nil
function scope.update(scope_resolver)
    scope_resolver = scope.find_resolver(scope_resolver)
    scope_resolver = update_autocmd(scope_resolver)

    local scope_path = scope.resolve(scope_resolver.resolve)
    if scope_resolver.cache ~= false then
        log.debug("Updating scope cache. Cache key: " .. tostring(scope_resolver.key))
        cached_paths[scope_resolver.key] = scope_path
    end

    return scope_path
end

---@param scope_function Grapple.ScopeFunction
---@return Grapple.ScopePath | nil
function scope.resolve(scope_function)
    local ok, scope_path = pcall(scope_function)
    if not ok or type(scope_path) ~= "string" then
        log.warn("Unable to resolve scope. Ok: " .. tostring(ok) .. ". Result: " .. vim.inspect(scope_path))
        return nil
    end
    return scope_path
end

---@param scope_type Grapple.ScopeType
---@return boolean
function scope.cached(scope_type)
    local scope_resolver = scope.find_resolver(scope_type)
    return cached_paths[scope_resolver.key] ~= nil
end

---@param scope_type Grapple.ScopeType
function scope.invalidate(scope_type)
    local scope_resolver = scope.find_resolver(scope_type)
    log.debug("Invalidating scope cache. Cache key: " .. tostring(scope_resolver.key))
    cached_paths[scope_resolver.key] = nil
end

return scope
