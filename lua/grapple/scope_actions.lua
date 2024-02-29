local ScopeActions = {}

---@class grapple.action.scope_options
---
---User-provided information
---@field name? string

---@param opts grapple.action.scope_options
---@return string? error
function ScopeActions.select(opts)
    require("grapple").use_scope(opts.name)
end

return ScopeActions
