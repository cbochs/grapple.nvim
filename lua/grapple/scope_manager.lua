---@class ScopeManager
---@field scopes table<string, Scope>
local ScopeManager = {}
ScopeManager.__index = ScopeManager

---@return ScopeManager
function ScopeManager:new()
    return setmetatable({
        scopes = {},
    }, self)
end

---@param scope_name string
---@return Scope, string? error
function ScopeManager:get(scope_name)
    local scope = self.scopes[scope_name]
    if not scope then
        return {}, string.format("Could not find scope %s", scope_name)
    end
    return scope, nil
end
