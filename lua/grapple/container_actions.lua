local ContainerActions = {}

---@class grapple.action.container_options
---
---User-provided information
---@field id? string

---@param opts grapple.action.container_options
---@return string? error
function ContainerActions.select(opts)
    require("grapple").open_tags({ id = opts.id })
end

---@param opts grapple.action.container_options
---@return string? error
function ContainerActions.reset(opts)
    require("grapple").reset({ id = opts.id })
end

return ContainerActions
