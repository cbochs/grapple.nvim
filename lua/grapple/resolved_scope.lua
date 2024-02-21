---@class grapple.scope.resolved
---@field id string uniquely identifies a scope
---@field path string an absolute path
---@field persisted boolean
---@field tag_manager grapple.tag.manager
local ResolvedScope = {}
ResolvedScope.__index = ResolvedScope

---@param id string
---@param path string | nil
---@param persisted boolean
---@param tag_manager grapple.tag.manager
---@return grapple.scope.resolved
function ResolvedScope:new(id, path, persisted, tag_manager)
    return setmetatable({
        id = id,
        path = path,
        persisted = persisted,
        tag_manager = tag_manager,
    }, self)
end

---@param callback fun(container: grapple.tag.container): string?
---@return string? error
function ResolvedScope:enter(callback)
    return self.tag_manager:transaction(self.id, callback, { sync = self.persisted })
end

---@return grapple.tag[], string? error
function ResolvedScope:tags()
    local container, err = self.tag_manager:container(self.id)
    if err then
        return {}, err
    end

    return container.tags, nil
end

return ResolvedScope
