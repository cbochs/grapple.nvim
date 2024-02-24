---@class grapple.scope.resolved
---@field name string scope name
---@field id string uniquely identifies a scope
---@field path string an absolute path
---@field tag_manager grapple.tag.manager
local ResolvedScope = {}
ResolvedScope.__index = ResolvedScope

---@param name string
---@param id string
---@param path string | nil
---@param tag_manager grapple.tag.manager
---@return grapple.scope.resolved
function ResolvedScope:new(name, id, path, tag_manager)
    return setmetatable({
        name = name,
        id = id,
        path = path,
        tag_manager = tag_manager,
    }, self)
end

---@param callback fun(container: grapple.tag.container): string?
---@return string? error
function ResolvedScope:enter(callback)
    return self.tag_manager:transaction(self.id, callback)
end

---@return grapple.tag[] | nil, string? error
function ResolvedScope:tags()
    local container, err = self.tag_manager:container(self.id)
    if not container then
        return nil, err
    end

    return container.tags, nil
end

return ResolvedScope
