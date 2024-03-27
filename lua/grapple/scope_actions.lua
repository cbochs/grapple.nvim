local ScopeActions = {}

---@class grapple.action.scope_options
---
---Provided by Window
---@field window grapple.window
---
---Provided by ScopeContent
---@field show_all boolean
---
---User-provided information
---@field name? string

---@param opts grapple.action.scope_options
function ScopeActions.change(opts)
    require("grapple").use_scope(opts.name)
    require("grapple").open_tags()
end

---@param opts grapple.action.scope_options
function ScopeActions.open_tags(opts)
    require("grapple").open_tags({ scope = opts.name })
end

function ScopeActions.open_loaded()
    require("grapple").open_loaded()
end

function ScopeActions.toggle_all(opts)
    -- HACK: reduce window flickering by updating the content in-place
    opts.window.content.show_all = not opts.show_all
    opts.window:render()
end

return ScopeActions
