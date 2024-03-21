local TagContainer = require("grapple.tag_container")
local Util = require("grapple.util")

---@class grapple.tag_manager
---@field state grapple.state
---@field containers table<string, grapple.tag_container>
local TagManager = {}
TagManager.__index = TagManager

---@param app grapple.app
---@param state grapple.state
---@return grapple.tag_manager
function TagManager:new(app, state)
    return setmetatable({
        app = app,
        state = state,
        containers = {},
    }, self)
end

---@param opts grapple.options
---@return string[] errors
function TagManager:update_all(opts)
    local errors = {}

    for _, id in ipairs(vim.tbl_keys(self.containers)) do
        local err = self:transaction(id, function(container)
            return container:update(opts)
        end)

        if err then
            table.insert(errors, err)
        end
    end

    return errors
end

---@param id string
---@param callback fun(container: grapple.tag_container): string?
---@param opts? { sync?: boolean }
---@return string? error
function TagManager:transaction(id, callback, opts)
    opts = vim.tbl_extend("keep", opts or {}, {
        sync = true,
    })

    local container, err = self:load(id)
    if not container then
        return err
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = callback(container)
    if err then
        return err
    end

    vim.api.nvim_exec_autocmds("User", {
        pattern = "GrappleUpdate",
        modeline = false,
    })

    if opts.sync then
        ---@diagnostic disable-next-line: redefined-local
        local err = self:sync(id)
        if err then
            return err
        end
    end

    return nil
end

---@alias grapple.tag_container_item { container: grapple.tag_container | nil, loaded: boolean}
---
---@return grapple.tag_container_item[]
function TagManager:list()
    local list = {}

    for _, id in ipairs(self.state:list()) do
        ---@type grapple.tag_container_item
        local item = {
            id = id,
            container = self:get(id),
            loaded = self:is_loaded(id),
        }

        table.insert(list, item)
    end

    return list
end

---@param id string
---@return grapple.tag_container | nil
function TagManager:get(id)
    return self.containers[id]
end

---@param id string
---@return boolean
function TagManager:is_loaded(id)
    return self.containers[id] ~= nil
end

---@param id string
---@return grapple.tag_container | nil, string? error
function TagManager:load(id)
    if self:is_loaded(id) then
        return self.containers[id], nil
    end

    if not self.state:exists(id) then
        local container = TagContainer:new(id)
        self.containers[id] = container

        return container, nil
    end

    local tbl, err = self.state:read(id)
    if err then
        return nil, err
    end

    ---@diagnostic disable-next-line: redefined-local
    local container, err = TagContainer.from_table(tbl)
    if not container then
        return nil, err
    end

    self.containers[id] = container

    return container, nil
end

---@param id string
function TagManager:unload(id)
    self.containers[id] = nil
end

---@param id string
---@return string? error
function TagManager:reset(id)
    self:unload(id)

    if self.state:exists(id) then
        local err = self.state:remove(id)
        if err then
            return err
        end
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
        return err
    end
end

return TagManager
