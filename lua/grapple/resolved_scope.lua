---@class grapple.resolved_scope
---@field app grapple.app
---@field name string scope name
---@field id string uniquely identifies a scope
---@field path string an absolute path
---@field tag_manager grapple.tag_manager
local ResolvedScope = {}
ResolvedScope.__index = ResolvedScope

---@param app grapple.app
---@param name string
---@param id string
---@param path string | nil
---@param tag_manager grapple.tag_manager
---@return grapple.resolved_scope
function ResolvedScope:new(app, name, id, path)
    return setmetatable({
        app = app,
        name = name,
        id = id,
        path = path or vim.loop.cwd(),
    }, self)
end

---Implements Resolvable
---@return grapple.resolved_scope | nil, string? error
function ResolvedScope:resolve()
    return self
end

---@param callback fun(container: grapple.tag_container): string?
---@param opts? { sync?: boolean }
---@return string? error
function ResolvedScope:enter(callback, opts)
    return self.app.tag_manager:transaction(self.id, callback, opts)
end

---@return grapple.tag[] | nil, string? error
function ResolvedScope:tags()
    local container, err = self.app.tag_manager:load(self.id)
    if not container then
        return nil, err
    end

    return container.tags, nil
end

return ResolvedScope
