local log = require("grapple.log")

local M = {}

---@alias Grapple.ScopeResolver fun(): string

---@enum Grapple.Scope
M.Scope = {
    ---Tags are ephemeral and are deleted on exit
    NONE = "none",

    ---Use a global namespace for tags
    GLOBAL = "global",

    ---Use the current working directory as the tag namespace
    DIRECTORY = "directory",

    ---Use the reported "root_dir" from LSP clients as the tag namespace
    LSP = "lsp",
}

---@param scope Grapple.Scope
---@return string
function M.resolve(scope)
    local scope_key

    -- Perform scope resolution
    if scope == M.Scope.NONE then
        scope_key = "none"
    elseif scope == M.Scope.GLOBAL then
        scope_key = "global"
    elseif scope == M.Scope.DIRECTORY then
        scope_key = vim.fn.getcwd()
    elseif scope == M.Scope.LSP then
        -- This scope is falliable
        --
        -- There's no good way to disambiguate which client to use when multiple
        -- are present. For that reason, we choose to take the first active
        -- client that is attached to the current buffer.
        local clients = vim.lsp.get_active_clients({ bufnr = 0 })
        if #clients > 0 then
            local client = clients[1]
            scope_key = client.config.root_dir
        end
    elseif type(scope) == "function" then
        -- This scope is falliable
        local resolved_scope = scope()
        if type(resolved_scope) == "string" then
            scope_key = resolved_scope
        else
            log.warn("Unable to resolve custom scope to a string scope key. Resolved to " .. tostring(resolved_scope))
        end
    end

    -- Always fallback to the DIRECTORY scope
    if scope_key == nil then
        scope_key = M.resolve(M.Scope.DIRECTORY)
    end

    -- By this point, scope_key is guaranteed to have been resolved
    ---@type string
    scope_key = scope_key

    return scope_key
end

return M
