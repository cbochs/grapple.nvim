local ScopeActions = {}

---@class grapple.action.container_options
---
---User-provided information
---@field id? string

---@param opts grapple.action.container_options
---@return string? error
function ScopeActions.select(opts)
    require("grapple").open_tags({ id = opts.id })
end

return ScopeActions
