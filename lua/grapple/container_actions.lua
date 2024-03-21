local ContainerActions = {}

---@class grapple.action.container_options
---
---Provided by Window
---@field window grapple.window
---
---Provided by ContainerContent
---@field show_all boolean
---
---User-provided information
---@field id? string

---@param opts grapple.action.container_options
function ContainerActions.select(opts)
    require("grapple").open_tags({ id = opts.id })
end

function ContainerActions.unload(opts)
    require("grapple").unload({ id = opts.id, notify = true })
    opts.window:render()
end

---@param opts grapple.action.container_options
function ContainerActions.reset(opts)
    require("grapple").reset({ id = opts.id, notify = true })
    opts.window:render()
end

---@param opts grapple.action.container_options
function ContainerActions.toggle_all(opts)
    -- HACK: reduce window flickering for now by updating the content in-place
    opts.window.content.show_all = not opts.show_all
    opts.window:render()
    -- require("grapple").open_loaded({ all = not opts.show_all })
end

function ContainerActions.open_scopes()
    require("grapple").open_scopes()
end

return ContainerActions
