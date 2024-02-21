local TagContainer = require("grapple.tag_container")
local StateManager = require("grapple.state_manager")

---@class grapple.tag.manager
---@field state grapple.state.manager
---@field containers table<string, grapple.tag.container>
local TagManager = {}
TagManager.__index = TagManager

---@param state grapple.state.manager
---@return grapple.tag.manager
function TagManager:new(state)
    return setmetatable({
        state = state,
        containers = {},
    }, self)
end

---@param id string
---@param callback fun(container: grapple.tag.container): string?
---@param opts? { sync?: boolean }
---@return string? error
function TagManager:transaction(id, callback, opts)
    local container, err = self:container(id)
    if err then
        return err
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = callback(container)
    if err then
        return err
    end

    if opts and opts.sync then
        ---@diagnostic disable-next-line: redefined-local
        local err = self:sync(id)
        if err then
            return err
        end
    end

    return nil
end

---@param id string
---@return grapple.tag.container, string? error
function TagManager:container(id)
    if self.containers[id] then
        return self.containers[id], nil
    end

    ---@diagnostic disable-next-line: redefined-local
    local tbl, err = self.state:read(id)
    if err and err:is(StateManager.NoExistError) then
        local container = TagContainer:new()
        self.containers[id] = container

        return container, nil
    end

    if err and not err:is(StateManager.NoExistError) then
        return {}, err:error()
    end

    ---@diagnostic disable-next-line: redefined-local
    local container, err = TagContainer.from_table(tbl)
    if err then
        return {}, err
    end

    self.containers[id] = container

    return container, nil
end

---@param id string
---@return string? error
function TagManager:reset(id)
    local container = self.containers[id]
    if not container then
        return string.format("no container for id: %s", id)
    end

    self.containers[id] = nil

    local err = self.state:remove(id)
    if err then
        return err:error()
    end
end

---@param id string
---@return string? error
function TagManager:sync(id)
    local container = self.containers[id]
    if not container then
        return string.format("no container for id: %s", id)
    end

    local err = self.state:write(id, container:into_table())
    if err then
        return err:error()
    end
end

return TagManager
