local log = require("grapple.log")

local scope = {}

---@class Grapple.ScopeOptions
---@field key string
---@field cache boolean | string | string[]
---@field persist boolean

---@alias Grapple.Scope string

---@alias Grapple.ScopeFunction fun(): Grapple.Scope | nil

---@class Grapple.ScopeResolver
---@field key Grapple.ScopeKey
---@field resolve Grapple.ScopeFunction
---@field cache boolean | string | string[]
---@field persist boolean | string | string[]
---@field autocmd number | nil

---@alias Grapple.ScopeKey string | integer

---@alias Grapple.ScopeResolverLike Grapple.ScopeKey | Grapple.ScopeResolver

---@type table<Grapple.ScopeKey, Grapple.Scope>
local cached_scopes = {}

---@type table<Grapple.ScopeKey, Grapple.ScopeResolver>
scope.resolvers = {}

scope.separator = "#"

---@private
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

---@private
function scope.reset()
    vim.api.nvim_create_augroup("GrappleScope", { clear = true })
    scope.resolvers = {}
    cached_scopes = {}
end

---@param scope_function Grapple.ScopeFunction
---@param opts? Grapple.ScopeOptions
---@return Grapple.ScopeResolver
function scope.resolver(scope_function, opts)
    opts = opts or {}

    if opts.key and scope.resolvers[opts.key] ~= nil then
        log.debug("Replacing existing scope resolver. key: " .. opts.key)

        local scope_resolver = scope.resolvers[opts.key]
        if scope_resolver.autocmd ~= nil then
            vim.api.nvim_del_autocmd(scope_resolver.autocmd)
        end

        scope.invalidate(scope_resolver)
        scope.resolvers[scope_resolver.key] = nil
    end

    -- Scope resolver defaults
    local scope_key = opts.key or (#scope.resolvers + 1)
    local scope_cache = true
    local scope_persist = true

    if opts.key ~= nil then
        scope_key = opts.key
    end
    if opts.cache ~= nil then
        scope_cache = opts.cache
    end
    if opts.persist ~= nil then
        scope_persist = opts.persist
    end

    ---@type Grapple.ScopeResolver
    local scope_resolver = {
        key = scope_key,
        resolve = scope_function,
        cache = scope_cache,
        persist = scope_persist,
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
---@param opts? Grapple.Options
---@return Grapple.ScopeResolver
function scope.fallback(scope_resolvers, opts)
    return scope.resolver(function()
        for _, scope_resolver in ipairs(scope_resolvers) do
            local scope_path = scope.get_safe(scope_resolver)
            if scope_path ~= nil then
                return scope_path
            end
        end
    end, vim.tbl_extend("force", { cache = false }, opts or {}))
end

---@param path_resolver Grapple.ScopeResolver
---@param suffix_resolver Grapple.ScopeResolver
---@param opts Grapple.ScopeOptions
---@return Grapple.ScopeResolver
function scope.suffix(path_resolver, suffix_resolver, opts)
    return scope.resolver(function()
        local scope_path = scope.get_safe(path_resolver)
        if scope_path == nil then
            return
        end

        local scope_suffix = scope.get_safe(suffix_resolver)
        if scope_suffix == nil then
            return scope_path
        end

        return scope_path .. scope.separator .. scope_suffix
    end, vim.tbl_extend("force", { cache = false }, opts or {}))
end

---@param plain_string string
---@param opts Grapple.ScopeOptions
---@return Grapple.ScopeResolver
function scope.static(plain_string, opts)
    return scope.resolver(function()
        return plain_string
    end, vim.tbl_extend("force", { cache = false }, opts or {}))
end

---@private
---@param scope_resolver Grapple.ScopeResolverLike
---@return Grapple.ScopeResolver
function scope.find_resolver(scope_resolver)
    if scope_resolver == nil then
        log.error("Input scope resolver is nil.")
        error("Input scope resolver is nil.")
    end
    if type(scope_resolver) == "string" then
        scope_resolver = scope.resolvers[scope_resolver]
        if scope_resolver == nil then
            log.error(string.format("Unable to find scope resolver for key: %s", scope_resolver))
            error(string.format("Unable to find scope resolver for key: %s", scope_resolver))
        end
    end
    return scope_resolver
end

---@param scope_resolver Grapple.ScopeResolverLike
---@return Grapple.Scope
function scope.get(scope_resolver)
    local scope_ = scope.get_safe(scope_resolver)
    if scope_ == nil then
        log.error(string.format("Unable to find scope for resolver: %s", vim.inspect(scope_resolver)))
        error(string.format("Unable to find scope for resolver: %s", vim.inspect(scope_resolver)))
    end
    return scope_
end

---@param scope_resolver Grapple.ScopeResolverLike
---@return Grapple.Scope | nil
function scope.get_safe(scope_resolver)
    scope_resolver = scope.find_resolver(scope_resolver)
    if cached_scopes[scope_resolver.key] ~= nil then
        return cached_scopes[scope_resolver.key]
    end
    return scope.update(scope_resolver)
end

---@param scope_resolver Grapple.ScopeResolverLike
---@return boolean
function scope.cached(scope_resolver)
    scope_resolver = scope.find_resolver(scope_resolver)
    return cached_scopes[scope_resolver.key] ~= nil
end

---@param scope_resolver Grapple.ScopeResolverLike
function scope.invalidate(scope_resolver)
    scope_resolver = scope.find_resolver(scope_resolver)
    log.debug("Invalidating scope cache for key: " .. tostring(scope_resolver.key))
    cached_scopes[scope_resolver.key] = nil
end

---@private
---@param scope_resolver Grapple.ScopeResolver
---@return Grapple.Scope | nil
function scope.update(scope_resolver)
    scope_resolver = update_autocmd(scope_resolver)

    local resolved_scope = scope.resolve(scope_resolver)
    if scope_resolver.cache ~= false then
        log.debug("Updating scope cache for key: " .. tostring(scope_resolver.key))
        cached_scopes[scope_resolver.key] = resolved_scope
    end

    return resolved_scope
end

---@private
---@param scope_resolver Grapple.ScopeResolver
---@return Grapple.Scope | nil
function scope.resolve(scope_resolver)
    local ok, scope_path = pcall(scope_resolver.resolve)
    if not ok or type(scope_path) ~= "string" then
        log.debug(
            string.format(
                "Unable to resolve scope. ok: %s. result: %s. resolver: %s",
                ok,
                scope_path,
                vim.inspect(scope_resolver)
            )
        )
        return nil
    end
    return scope_path
end

---@private
---@param scope_ Grapple.Scope
---@return string
function scope.scope_path(scope_)
    return scope.scope_parts(scope_)[1]
end

---@private
---@param scope_ Grapple.Scope
---@return string | nil
function scope.scope_suffix(scope_)
    return scope.scope_suffixes(scope_)[-1]
end

---@private
---@param scope_ Grapple.Scope
---@return string[]
function scope.scope_suffixes(scope_)
    local parts = scope.scope_parts(scope_)
    if #parts == 1 then
        return {}
    end
    return { unpack(parts, 2) }
end

---@private
---@param scope_ Grapple.Scope
---@return string[]
function scope.scope_parts(scope_)
    if scope_ == nil then
        return {}
    end

    local parts = {}
    for _, part in string.gmatch(scope_, scope.separator) do
        table.insert(parts, part)
    end
    return parts
end

return scope
