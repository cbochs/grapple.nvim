local TagContainer = require("grapple.tag_container")

---@class grapple.tag_manager
---@field state grapple.state
---@field containers table<string, grapple.tag_container>
local TagManager = {}
TagManager.__index = TagManager

---@param state grapple.state
---@return grapple.tag_manager
function TagManager:new(state)
    return setmetatable({
        state = state,
        containers = {},
    }, self)
end

---@class grapple.tag_container_item
---@field id string
---@field loaded boolean
---@field container? grapple.tag_container

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

---@param time_limit integer | string
---@return string[] | nil pruned, string? error
function TagManager:prune(time_limit)
    vim.validate({
        time_limit = { time_limit, { "number", "string" } },
    })

    local limit_sec
    if type(time_limit) == "number" then
        limit_sec = time_limit
    elseif type(time_limit) == "string" then
        local n, kind = string.match(time_limit, "^(%d+)(%S)$")
        if not n or not kind then
            return nil, string.format("Could not parse time limit: %s", time_limit)
        end

        n = assert(tonumber(n))
        if kind == "d" then
            limit_sec = n * 24 * 60 * 60
        elseif kind == "h" then
            limit_sec = n * 60 * 60
        elseif kind == "m" then
            limit_sec = n * 60
        elseif kind == "s" then
            limit_sec = n
        else
            return nil, string.format("Invalid time limit kind: %s", time_limit)
        end
    else
        return nil, string.format("Invalid time limit: %s", vim.inspect(time_limit))
    end

    local pruned_ids, err = self.state:prune(limit_sec)
    if not pruned_ids then
        return nil, err
    end

    return pruned_ids, nil
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
