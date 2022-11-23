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

---@alias Grapple.ScopeType Grapple.ScopePath | Grapple.ScopeResolver

---@type table<Grapple.ScopeKey, Grapple.ScopePath>
local cached_paths = {}

---@type table<Grapple.ScopeKey, Grapple.ScopeResolver>
local resolvers = {}

---@type table<string, Grapple.ScopeResolver>
M.builtin = {
    ---Tags are ephemeral and are deleted on exit
    none = M.resolver(function()
        return "__none__"
    end, {}),

    ---Use a global namespace for tags
    global = M.resolver(function()
        return "__global__"
    end, {}),

    ---Use the working directory set at startup
    static = M.resolver(function()
        return vim.fn.getcwd()
    end, {}),

    ---Use the current working directory as the tag namespace
    directory = M.resolver(function()
        return vim.fn.getcwd()
    end, { invalidates = "DirChanged" }),

    ---Use the reported "root_dir" from LSP clients as the tag namespace
    lsp = M.resolver(function()
        local clients = vim.lsp.get_active_clients({ bufnr = 0 })
        if #clients > 0 then
            local client = clients[1]
            return client.config.root_dir
        end
    end, { invalidates = { "LspAttach", "LspDetach" } }),
}

---@param scope_resolver Grapple.ScopeKey | Grapple.ScopeResolver
---@return Grapple.ScopeResolver | Grapple.ScopePath
local function find_resolver(scope_resolver)
    -- The scope type is a scope resolver
    if type(scope_resolver) == "table" then
        if scope_resolver.key == nil or scope_resolver.resolve == nil then
            log.error("Invalid scope resolver. Resolver: " .. vim.inspect(scope_resolver))
            error("Invalid scope resolver. Resolver: " .. vim.inspect(scope_resolver))
        end
        return scope_resolver
    end

    -- The scope type is a known scope resolver
    if resolvers[scope_resolver] ~= nil then
        return resolvers[scope_resolver]
    end

    log.error("Unable to find scope resolver. Scope: " .. tostring(scope_resolver))
    error("Unable to find scope resolver. Scope: " .. tostring(scope_resolver))
end

---@param maybe_scope_path any
---@return boolean
local function is_scope_path(maybe_scope_path)
    if type(maybe_scope_path) ~= "string" then
        return false
    end
    if vim.tbl_contains(vim.tbl_values(cached_paths), maybe_scope_path) then
        return true
    end
    return false
end

---@param scope_function Grapple.ScopeFunction
---@param opts Grapple.ScopeOptions
---@return Grapple.ScopeResolver
function M.resolver(scope_function, opts)
    if opts.key and resolvers[opts.key] ~= nil then
        -- todo(cbochs): demote this to a warning and properly clear scope resolver
        -- and its autocommands to make way for the new resolver. In addition,
        -- the scope must be invalidated
        log.error("Scope resolvers cannot be overridden.")
        error("Scope resolvers cannot be overridden.")
    end

    local scope_key = opts.key or (#resolvers + 1)

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

    resolvers[scope_key] = scope_resolver

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
---@return Grapple.ScopePath | nil
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

---@param scope_type Grapple.ScopeType
---@return Grapple.ScopePath | nil
function M.get(scope_type)
    if is_scope_path(scope_type) then
        return scope_type
    end

    local scope_resolver = find_resolver(scope_type)
    if cached_paths[scope_resolver] ~= nil then
        return cached_paths[scope_resolver]
    end

    return M.update(scope_type)
end

---@param scope_type Grapple.ScopeType
---@return Grapple.ScopePath | nil
function M.update(scope_type)
    if is_scope_path(scope_type) then
        return scope_type
    end

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
