---@class grapple.resolved_scope
---@field name string? scope name
---@field id string uniquely identifies a scope
---@field path string an absolute path
---@field tag_manager grapple.tag_manager
local ResolvedScope = {}
ResolvedScope.__index = ResolvedScope

---@param name string | nil
---@param id string
---@param path string | nil
---@return grapple.resolved_scope
function ResolvedScope:new(name, id, path)
    return setmetatable({
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

return ResolvedScope
