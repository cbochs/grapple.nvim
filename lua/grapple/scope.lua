local log = require("grapple.log")
local types = require("grapple.types")

local M = {}

---@alias Grapple.ScopePath string

---@alias Grapple.Scope Grapple.ScopeType | Grapple.ScopeResolver | Grapple.ScopePath

---@alias Grapple.ScopeResolver fun(): Grapple.ScopePath | nil

---@type table<Grapple.ScopeType, Grapple.ScopeResolver>
M.resolvers = {
    [types.scope.none] = function()
        return "__none__"
    end,
    [types.scope.global] = function()
        return "__global__"
    end,
    [types.scope.static] = function()
        return vim.fn.getcwd()
    end,
    [types.scope.directory] = function()
        return vim.fn.getcwd()
    end,
    [types.scope.git] = function()
        return M.root({ ".git" })
    end,
    [types.scope.lsp] = function()
        local clients = vim.lsp.get_active_clients({ bufnr = 0 })
        if #clients > 0 then
            local client = clients[1]
            return client.config.root_dir
        end
    end,
}

---@type Grapple.ScopeResolver
local current_scope = nil

---@type table<Grapple.ScopeResolver, Grapple.ScopePath>
local cached_paths = {}

---@param scope Grapple.Scope | nil
---@return Grapple.ScopeResolver | nil
local function find_resolver(scope)
    if scope == nil and current_scope ~= nil then
        return current_scope
    end
    if type(scope) == "function" then
        return scope
    end
    if M.resolvers[scope] ~= nil then
        return M.resolvers[scope]
    end
end

---@param root_names string[]
---@return Grapple.ScopeResolver
function M.root(root_names)
    root_names = root_names or { ".git" }
    return function()
        local root_files = vim.fs.find(root_names, { upward = true })
        if #root_files > 0 then
            return vim.fs.dirname(root_files[1])
        end
        return nil
    end
end

---@param scope? Grapple.Scope
---@return Grapple.ScopePath | nil
function M.get(scope)
    local scope_resolver = find_resolver(scope)
    if cached_paths[scope_resolver] ~= nil then
        return cached_paths[scope_resolver]
    end

    if scope_resolver == nil then
        if vim.tbl_contains(vim.tbl_values(cached_paths), scope) then
            return scope
        end
        error("Unable to get scope path. Scope: " .. tostring(scope))
    end

    return M.update(scope)
end

---@param scope Grapple.Scope
function M.set(scope)
    local scope_resolver = find_resolver(scope)
    if scope_resolver == nil then
        error("Unable to set scope. Scope: " .. tostring(scope))
    end
    current_scope = scope_resolver
end

---@param scope? Grapple.Scope
function M.update(scope)
    local scope_resolver = find_resolver(scope)
    cached_paths[scope] = M.resolve(scope_resolver)
    return cached_paths[scope]
end

---@param scope_resolver Grapple.ScopeResolver
---@return Grapple.ScopePath | nil
function M.resolve(scope_resolver)
    local ok, scope_path = pcall(scope_resolver)
    if not ok or type(scope_path) ~= "string" then
        log.warn("Unable to resolve scope. Resolved to: " .. tostring(scope_path))
    end
    return scope_path
end

---@param scope? Grapple.Scope
function M.invalidate(scope)
    if scope == nil then
        cached_paths = {}
    end
    scope = find_resolver(scope)
    cached_paths[scope] = nil
end

return M
