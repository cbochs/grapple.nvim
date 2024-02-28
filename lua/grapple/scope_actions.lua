local ScopeActions = {}

---@class grapple.action.scope_options
---
---User-provided information
---@field name? string

---@param opts grapple.action.scope_options
---@return string? error
function ScopeActions.select(opts)
    local app = require("grapple.app").get()

    local scope, err = app.scope_manager:get(opts.name)
    if not scope then
        return err
    end

    app.settings:update({ scope = scope.name })

    return nil
end

return ScopeActions
