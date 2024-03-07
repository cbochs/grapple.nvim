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
    local App = require("grapple.app")
    local app = App.get()

    local scope = entity.scope

    -- A string representation of the index
    local id = string.format("/%03d", index)

    -- In compliance with "grapple" syntax
    local line = string.format("%s %s %s", id, scope.name, scope.desc)
    local min_col = assert(string.find(line, "%s")) -- width of id

    local name_group = "GrappleBold"
    local sign_highlight

    if app.settings.status and entity.current then
        sign_highlight = "GrappleCurrent"
        name_group = "GrappleCurrentBold"
    end

    local col_start = string.find(line, "%s")
    local col_end = col_start + string.len(scope.name)
    local name_highlight = {
        hl_group = name_group,
        line = index - 1,
        col_start = col_start,
        col_end = col_end,
    }

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
        highlights = { name_highlight },

        ---@type grapple.vim.extmark[]
        extmarks = {
            {
                line = index - 1,
                col = 0,
                opts = {
                    sign_text = string.format("%d", index),
                    sign_hl_group = sign_highlight,

                    -- TODO: requires nvim-0.10
                    -- invalidate = true,
                },
            },
        },
    }

    return entry
end

---Safety: assume that the content is unmodifiable and the ID
---can always be parsed
---@param line string
---@param original_entries grapple.window.entry[]
---@return grapple.window.parsed_entry
function ScopeContent:parse_line(line, original_entries)
    local id, _ = string.match(line, "^/(%d+) (%S+) %S+")
    local index = assert(tonumber(id))

    ---@type grapple.window.parsed_entry
    ---@diagnostic disable-next-line: assign-type-mismatch
    local entry = vim.deepcopy(original_entries[index])

    return entry
end

---@param action grapple.action
---@param opts? grapple.action.options
---@return string? error
function ScopeContent:perform(action, opts)
    return action(opts)
end

return ScopeContent
