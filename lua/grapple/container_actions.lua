local ContainerActions = {}

---@class grapple.action.container_options
---
---User-provided information
---@field id? string

---@param opts grapple.action.container_options
function ContainerActions.select(opts)
    require("grapple").open_tags({ id = opts.id })
end

---@param opts grapple.action.container_options
function ContainerActions.reset(opts)
    require("grapple").reset({ id = opts.id })
end

function ContainerActions.open_scopes()
    require("grapple").open_scopes()
end

return ContainerActions
