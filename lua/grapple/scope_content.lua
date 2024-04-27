local Util = require("grapple.util")

---@class grapple.scope_content
---@field app grapple.app
---@field hook_fn grapple.hook_fn
---@field title_fn grapple.title_fn
---@field show_all boolean
local ScopeContent = {}
ScopeContent.__index = ScopeContent

---@param app grapple.app
---@param hook_fn? grapple.hook_fn
---@param title_fn? grapple.title_fn
---@param show_all boolean
---@return grapple.scope_content
function ScopeContent:new(app, hook_fn, title_fn, show_all)
    return setmetatable({
        app = app,
        hook_fn = hook_fn,
        title_fn = title_fn,
        show_all = show_all,
    }, self)
end

---@return boolean
function ScopeContent:modifiable()
    return false
end

---Return the first editable cursor column for a line (0-indexed)
---@param _ string line
function ScopeContent:minimum_column(_)
    -- Assume: buffer is unmodifiable line contains two items: an id and path
    -- The id is in the form "/000" and followed by a space. Therefore the
    -- minimum column should be at 5 (0-indexed)
    return 5
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
    local scopes = self.app:list_scopes()
    local entities = {}

    for _, scope in ipairs(scopes) do
        if not self.show_all and scope.hidden then
            goto continue
        end

        ---@class grapple.scope_content.entity
        local entity = {
            scope = scope,
            current = scope.name == self.app.settings.scope,
        }

        table.insert(entities, entity)

        ::continue::
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
    local line = string.format("%s %s %s", id, scope.name, scope.desc or "")
    local min_col = assert(string.find(line, "%s")) -- width of id

    local name_group = "GrappleBold"
    local sign_highlight

    if self.app.settings.status and entity.current then
        sign_highlight = "GrappleCurrent"
        name_group = "GrappleCurrent"
    end

    local col_start, col_end = string.find(line, scope.name)
    local name_highlight = {
        hl_group = name_group,
        line = index - 1,
        col_start = col_start - 1,
        col_end = col_end,
    }

    -- Define line extmarks
    ---@type grapple.vim.extmark[]
    local extmarks = {}

    ---@type grapple.vim.mark
    local sign_mark
    local quick_select = self.app.settings:quick_select()[index]
    if quick_select then
        sign_mark = {
            sign_text = string.format("%s", quick_select),
            sign_hl_group = sign_highlight,
        }
    end

    extmarks = vim.tbl_filter(Util.not_nil, { sign_mark })
    extmarks = vim.tbl_map(function(mark)
        return {
            line = index - 1,
            col = 0,
            opts = mark,
        }
    end, extmarks)

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
        extmarks = extmarks,
    }

    return entry
end

---Safety: assume that the content is unmodifiable and the ID
---can always be parsed
---@param line string
---@param original_entries grapple.window.entry[]
---@return grapple.window.parsed_entry
function ScopeContent:parse_line(line, original_entries)
    local id = string.match(line, "^/(%d+)")
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
    opts = vim.tbl_extend("force", opts or {}, {
        show_all = self.show_all,
    })

    return action(opts)
end

return ScopeContent
