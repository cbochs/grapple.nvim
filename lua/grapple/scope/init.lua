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
---@field autocmd integer | nil

---@alias Grapple.ScopeType Grapple.ScopeKey | Grapple.ScopeResolver

---@alias Grapple.Scope Grapple.ScopePath | Grapple.ScopeType

---@type table<Grapple.ScopeKey, Grapple.ScopePath>
local cached_paths = {}

---@type table<Grapple.ScopeKey, Grapple.ScopeResolver>
M.resolvers = {}

---@param scope_type Grapple.ScopeType
---@return Grapple.ScopeResolver
local function find_resolver(scope_type)
    if M.resolvers[scope_type] ~= nil then
        return M.resolvers[scope_type]
    end

    if type(scope_type) == "table" then
        if scope_type.key == nil or scope_type.resolve == nil then
            log.error("Invalid scope resolver. Resolver: " .. vim.inspect(scope_type))
            error("Invalid scope resolver. Resolver: " .. vim.inspect(scope_type))
        end
        return scope_type
    end

    log.error("Unable to find scope resolver. Scope: " .. tostring(scope_type))
    error("Unable to find scope resolver. Scope: " .. tostring(scope_type))
end

---@param scope_function Grapple.ScopeFunction
---@param opts? Grapple.ScopeOptions
---@return Grapple.ScopeResolver
function M.resolver(scope_function, opts)
    opts = opts or {}

    if opts.key and M.resolvers[opts.key] ~= nil then
        -- todo(cbochs): demote this to a warning and properly clear scope resolver
        -- and its autocommands to make way for the new resolver. In addition,
        -- the scope must be invalidated
        log.error("Scope resolvers cannot be overridden.")
        error("Scope resolvers cannot be overridden.")
    end

    local scope_key = opts.key or (#M.resolvers + 1)

    local autocmd
    if opts.invalidates ~= nil then
        local group = vim.api.nvim_create_augroup("GrappleScope", { clear = false })
        autocmd = vim.api.nvim_create_autocmd(opts.invalidates, {
            group = group,
            callback = function()
                M.invalidate(scope_key)
            end,
        })
    end

    ---@type Grapple.ScopeResolver
    local scope_resolver = {
        key = scope_key,
        resolve = scope_function,
        autocmd = autocmd,
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

---@param scope_type Grapple.ScopeType
---@return Grapple.ScopePath | nil
function M.update(scope_type)
    local scope_resolver = find_resolver(scope_type)
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
