local ScopeActions = {}

---@class grapple.action.scope_options
---
---User-provided information
---@field name? string

---@param opts grapple.action.scope_options
function ScopeActions.select(opts)
    require("grapple").use_scope(opts.name)
    require("grapple").open_tags()
end

function ScopeActions.open_loaded()
    require("grapple").open_loaded()
end

return ScopeActions
