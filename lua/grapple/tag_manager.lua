local TagContainer = require("grapple.tag_container")

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

---@param opts grapple.tag.container.get
---@return boolean success, string[] errors
function TagManager:update(opts)
    local errors = {}

    for _, id in ipairs(vim.tbl_keys(self.containers)) do
        local err = self:transaction(id, function(container)
            local _, err = container:update(opts)
            if err then
                return err
            end
        end)

        if err then
            table.insert(errors, err)
        end
    end

    return (#errors == 0), errors
end

---@param id string
---@param callback fun(container: grapple.tag.container): string?
---@return string? error
function TagManager:transaction(id, callback)
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

    ---@diagnostic disable-next-line: redefined-local
    local err = self:sync(id)
    if err then
        return err
    end

    return nil
end

---@param id string
---@return grapple.tag.container | nil, string? error
function TagManager:load(id)
    if self.containers[id] then
        return self.containers[id], nil
    end

    if not self.state:exists(id) then
        local container = TagContainer:new()
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
---@return string? error
function TagManager:reset(id)
    self.containers[id] = nil

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
        return err:error()
    end
end

return TagManager
