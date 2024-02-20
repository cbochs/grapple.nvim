---@class grapple.scope.manager
---@field scopes table<string, grapple.scope>
local ScopeManager = {}
ScopeManager.__index = ScopeManager

---@return grapple.scope.manager
function ScopeManager:new()
    return setmetatable({
        scopes = {},
    }, self)
end

---@param scope_name string
---@return grapple.scope, string? error
function ScopeManager:get(scope_name)
    local scope = self.scopes[scope_name]
    if not scope then
        return {}, string.format("Could not find scope %s", scope_name)
    end
    return scope, nil
end
