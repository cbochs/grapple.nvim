local Path = require("grapple.path")

---@class grapple.container_content
---@field tag_manager grapple.tag_manager
---@field hook_fn grapple.hook_fn
---@field title_fn grapple.title_fn
local ContainerContent = {}
ContainerContent.__index = ContainerContent

---@param tag_manager grapple.tag_manager
---@param hook_fn? grapple.hook_fn
---@param title_fn? grapple.title_fn
---@return grapple.container_content
function ContainerContent:new(tag_manager, hook_fn, title_fn)
    return setmetatable({
        tag_manager = tag_manager,
        hook_fn = hook_fn,
        title_fn = title_fn,
    }, self)
end

---@return boolean
function ContainerContent:modifiable()
    return false
end

---@return string | nil title
function ContainerContent:title()
    if not self.title_fn then
        return
    end

    return self.title_fn()
end

---@param window grapple.window
---@return string? error
function ContainerContent:attach(window)
    if self.hook_fn then
        local err = self.hook_fn(window)
        if err then
            return err
        end
    end

    return nil
end

---@param window grapple.window
---@return string? error
---@diagnostic disable-next-line: unused-local
function ContainerContent:detach(window) end

---@param original grapple.window.entry
---@param parsed grapple.window.entry
---@return string? error
---@diagnostic disable-next-line: unused-local
function ContainerContent:sync(original, parsed) end

---@return grapple.window.entity[] | nil, string? error
function ContainerContent:entities()
    local App = require("grapple.app")
    local app = App.get()

    local current_scope, err = app:current_scope()
    if not current_scope then
        return nil, err
    end

    ---@param cont_a grapple.tag_container
    ---@param cont_b grapple.tag_container
    local function by_id(cont_a, cont_b)
        return string.lower(cont_a.id) < string.lower(cont_b.id)
    end

    local containers = vim.tbl_values(self.tag_manager.containers)
    table.sort(containers, by_id)

    local entities = {}

    for _, container in ipairs(containers) do
        ---@class grapple.container_content.entity
        local entity = {
            container = container,
            current = container.id == current_scope.id,
        }

        table.insert(entities, entity)
    end

    return entities, nil
end

---@param entity grapple.container_content.entity
---@param index integer
---@return grapple.window.entry
function ContainerContent:create_entry(entity, index)
    local App = require("grapple.app")
    local app = App.get()

    local container = entity.container

    -- A string representation of the index
    local id = string.format("/%03d", index)
    local rel_id = vim.fn.fnamemodify(container.id, ":~")

    -- In compliance with "grapple" syntax
    local line = string.format("%s %s", id, rel_id)
    local min_col = assert(string.find(line, "%s")) -- width of id

    local sign_highlight
    if app.settings.status and entity.current then
        sign_highlight = "GrappleCurrent"
    end

    ---@type grapple.window.entry
    local entry = {
        ---@class grapple.scope_content.data
        data = {
            id = container.id,
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
                sign_hl_group = sign_highlight,

                -- TODO: requires nvim-0.10
                -- invalidate = true,
            },
        },
    }

    return entry
end

---@param line string
---@return grapple.window.parsed_entry
function ContainerContent:parse_line(line)
    local id, container_id = string.match(line, "^/(%d+) (%S*)")
    local index = tonumber(id)

    ---@type grapple.window.parsed_entry
    local entry = {
        ---@type grapple.scope_content.data
        data = {
            id = Path.fs_absolute(container_id),
        },
        index = index,
        line = line,
    }

    return entry
end

---@param action grapple.action
---@param opts? grapple.action.options
---@return string? error
function ContainerContent:perform(action, opts)
    return action(opts)
end

return ContainerContent
