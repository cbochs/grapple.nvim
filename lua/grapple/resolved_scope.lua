---@class grapple.resolved_scope
---@field name string scope name
---@field id string uniquely identifies a scope
---@field path string an absolute path
---@field tag_manager grapple.tag_manager
local ResolvedScope = {}
ResolvedScope.__index = ResolvedScope

---@param name string
---@param id string
---@param path string | nil
---@param tag_manager grapple.tag_manager
---@return grapple.resolved_scope
function ResolvedScope:new(name, id, path, tag_manager)
    return setmetatable({
        name = name,
        id = id,
        path = path,
        tag_manager = tag_manager,
    }, self)
end

---@param callback fun(container: grapple.tag_container): string?
---@param opts? { sync?: boolean }
---@return string? error
function ResolvedScope:enter(callback, opts)
    return self.tag_manager:transaction(self.id, callback, opts)
end

---@return grapple.tag[] | nil, string? error
function ResolvedScope:tags()
    local container, err = self.tag_manager:load(self.id)
    if not container then
        return nil, err
    end

    return container.tags, nil
end

return ResolvedScope
