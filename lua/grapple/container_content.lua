---@class grapple.container_content
---@field tag_manager grapple.tag_manager
---@field hook_fn grapple.hook_fn
---@field title_fn grapple.title_fn
local TagContainerContent = {}
TagContainerContent.__index = TagContainerContent

---@param tag_manager grapple.tag_manager
---@param hook_fn? grapple.hook_fn
---@param title_fn? grapple.title_fn
---@return grapple.container_content
function TagContainerContent:new(tag_manager, hook_fn, title_fn)
    return setmetatable({
        tag_manager = tag_manager,
        hook_fn = hook_fn,
        title_fn = title_fn,
    }, self)
end

---@return boolean
function TagContainerContent:modifiable()
    return false
end

---@return string | nil title
function TagContainerContent:title()
    if not self.title_fn then
        return
    end

    return self.title_fn()
end

---@param window grapple.window
---@return string? error
function TagContainerContent:attach(window)
    if not self.hook_fn then
        return
    end

    local err = self.hook_fn(window)
    if err then
        return err
    end

    return nil
end

---@param window grapple.window
---@return string? error
---@diagnostic disable-next-line: unused-local
function TagContainerContent:detach(window) end

---@param original grapple.window.entry
---@param parsed grapple.window.entry
---@return string? error
---@diagnostic disable-next-line: unused-local
function TagContainerContent:sync(original, parsed) end

---@return grapple.window.entity[] | nil, string? error
function TagContainerContent:entities()
    ---@param id_a string
    ---@param id_b string
    local function by_name(id_a, id_b)
        return string.lower(id_a) < string.lower(id_b)
    end

    local containers = vim.tbl_values(self.tag_manager.containers)
    table.sort(containers, by_name)

    return containers, nil
end

---@param container grapple.tag_container
---@param index integer
---@return grapple.window.entry
function TagContainerContent:create_entry(container, index)
    -- A string representation of the index
    local id = string.format("/%03d", index)

    -- In compliance with "grapple" syntax
    local line = string.format("%s %s", id, container.name)
    local min_col = assert(string.find(line, "%s")) -- width of id

    ---@type grapple.window.entry
    local entry = {
        ---@class grapple.scope_content.data
        data = {
            name = container.name,
        },

        line = line,
        index = index,
        min_col = min_col,

        ---@type grapple.vim.highlight[]
        highlights = {},

        ---@type grapple.vim.extmark
        mark = {
            line = index - 1,
            col = 0,
            opts = {
                sign_text = string.format("%d", index),
                invalidate = true,
            },
        },
    }

    return entry
end

---@param line string
---@return grapple.window.parsed_entry
function TagContainerContent:parse_line(line)
    local id, name = string.match(line, "^/(%d+) (%S*)")
    local index = tonumber(id)

    ---@type grapple.window.parsed_entry
    local entry = {
        ---@type grapple.scope_content.data
        data = {
            name = name,
        },
        index = index,
        line = line,
    }

    return entry
end

---@param action grapple.action
---@param opts? grapple.action.options
---@return string? error
function TagContainerContent:perform(action, opts)
    return action(opts)
end

return TagContainerContent
