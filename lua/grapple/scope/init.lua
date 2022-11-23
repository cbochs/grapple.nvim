local log = require("grapple.log")

local M = {}

---@class Grapple.ScopeOptions
---@field key string
---@field invalidates string | string[] | nil

---@alias Grapple.ScopeKey string | integer

---@alias Grapple.ScopePath string

---@alias Grapple.ScopeFunction fun(): Grapple.ScopePath | nil

---@class Grapple.ScopeResolver
---@field key Grapple.ScopeKey
---@field resolve Grapple.ScopeFunction
---@field invalidates string | string[] | nil
---@field autocmd number | nil

---@alias Grapple.Scope Grapple.ScopePath | Grapple.ScopeKey | Grapple.ScopeResolver

---@type table<Grapple.ScopeKey, Grapple.ScopePath>
local cached_paths = {}

---@type table<Grapple.ScopeKey, Grapple.ScopeResolver>
M.resolvers = {}

---@param scope_resolver Grapple.ScopeKey | Grapple.ScopeResolver
---@return Grapple.ScopeResolver
local function find_resolver(scope_resolver)
    if M.resolvers[scope_resolver] ~= nil then
        return M.resolvers[scope_resolver]
    end

    if type(scope_resolver) == "table" then
        if scope_resolver.key == nil or scope_resolver.resolve == nil then
            log.error("Invalid scope resolver. Resolver: " .. vim.inspect(scope_resolver))
            error("Invalid scope resolver. Resolver: " .. vim.inspect(scope_resolver))
        end
        return scope_resolver
    end

    log.error("Unable to find scope resolver. Scope: " .. tostring(scope_resolver))
    error("Unable to find scope resolver. Scope: " .. tostring(scope_resolver))
end

---@param scope_resolver Grapple.ScopeKey | Grapple.ScopeResolver
---@return Grapple.ScopeResolver
local function update_autocmd(scope_resolver)
    scope_resolver = find_resolver(scope_resolver)
    if scope_resolver.invalidates == nil or scope_resolver.autocmd ~= nil then
        return scope_resolver
    end

    local group = vim.api.nvim_create_augroup("GrappleScope", { clear = false })
    scope_resolver.autocmd = vim.api.nvim_create_autocmd(scope_resolver.invalidates, {
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

    ---@type Grapple.ScopeResolver
    local scope_resolver = {
        key = scope_key,
        resolve = scope_function,
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
    opts = vim.tbl_extend("force", { invalidates = "DirChanged" }, opts or {})

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
    end, {})
end

---@param scope_type Grapple.Scope
---@return Grapple.ScopePath | nil
function M.get(scope_type)
    local scope_resolver = find_resolver(scope_type)
    if cached_paths[scope_resolver] ~= nil then
        return cached_paths[scope_resolver]
    end
    return M.update(scope_type)
end

---@param scope_type Grapple.ScopeKey | Grapple.ScopeResolver
---@return Grapple.ScopePath | nil
function M.update(scope_type)
    local scope_resolver = find_resolver(scope_type)
    scope_resolver = update_autocmd(scope_resolver)

    cached_paths[scope_resolver.key] = M.resolve(scope_resolver.resolve)
    return cached_paths[scope_type]
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
    cached_paths[scope_resolver.key] = nil
end

return M
