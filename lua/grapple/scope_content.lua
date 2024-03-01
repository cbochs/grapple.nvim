---@class grapple.scope_content
---@field scope_manager grapple.scope_manager
---@field hook_fn grapple.hook_fn
---@field title_fn grapple.title_fn
local ScopeContent = {}
ScopeContent.__index = ScopeContent

---@param scope_manager grapple.scope_manager
---@param hook_fn? grapple.hook_fn
---@param title_fn? grapple.title_fn
---@return grapple.scope_content
function ScopeContent:new(scope_manager, hook_fn, title_fn)
    return setmetatable({
        scope_manager = scope_manager,
        hook_fn = hook_fn,
        title_fn = title_fn,
    }, self)
end

---@return boolean
function ScopeContent:modifiable()
    return false
end

---@return string | nil title
function ScopeContent:title()
    if not self.title_fn then
        return
    end

    return self.title_fn()
end

---@param window grapple.window
---@return string? error
function ScopeContent:attach(window)
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
function ScopeContent:detach(window) end

---@param original grapple.window.entry
---@param parsed grapple.window.entry
---@return string? error
---@diagnostic disable-next-line: unused-local
function ScopeContent:sync(original, parsed) end

---@return grapple.window.entity[] | nil, string? error
function ScopeContent:entities()
    local App = require("grapple.app")
    local app = App.get()

    ---@param scope_a grapple.scope
    ---@param scope_b grapple.scope
    local function by_name(scope_a, scope_b)
        return string.lower(scope_a.name) < string.lower(scope_b.name)
    end

    local scopes = vim.tbl_values(self.scope_manager.scopes)
    table.sort(scopes, by_name)

    local entities = {}

    for _, scope in ipairs(scopes) do
        ---@class grapple.scope_content.entity
        local entity = {
            scope = scope,
            current = scope.name == app.settings.scope,
        }

        table.insert(entities, entity)
    end

    return entities, nil
end

---@param entity grapple.scope_content.entity
---@param index integer
---@return grapple.window.entry
function ScopeContent:create_entry(entity, index)
    local scope = entity.scope

    -- A string representation of the index
    local id = string.format("/%03d", index)

    -- In compliance with "grapple" syntax
    local line = string.format("%s %s %s", id, scope.name, scope.desc)
    local min_col = assert(string.find(line, "%s")) -- width of id

    local line_highlight
    if entity.current then
        line_highlight = {
            hl_group = "GrappleCurrent",
            line = index - 1,
            col_start = min_col,
            col_end = -1,
        }
    end

    ---@type grapple.window.entry
    local entry = {
        ---@class grapple.scope_content.data
        data = {
            name = scope.name,
        },

        line = line,
        index = index,
        min_col = min_col,

        ---@type grapple.vim.highlight[]
        highlights = { line_highlight },

        ---@type grapple.vim.extmark
        mark = {
            line = index - 1,
            col = 0,
            opts = {
                sign_text = string.format("%d", index),

                -- TODO: requires nvim-0.10
                -- invalidate = true,
            },
        },
    }

    return entry
end

---@param line string
---@return grapple.window.parsed_entry
function ScopeContent:parse_line(line)
    local id, name = string.match(line, "^/(%d+) (%S*)")
    local index = tonumber(id)

    ---@type grapple.window.parsed_entry
    local entry = {
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
function ScopeContent:perform(action, opts)
    return action(opts)
end

return ScopeContent
