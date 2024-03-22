local Path = require("grapple.path")
local Util = require("grapple.util")

---@class grapple.container_content
---@field app grapple.app
---@field hook_fn grapple.hook_fn
---@field title_fn grapple.title_fn
---@field show_all boolean
local ContainerContent = {}
ContainerContent.__index = ContainerContent

---@param app grapple.app
---@param hook_fn? grapple.hook_fn
---@param title_fn? grapple.title_fn
---@param show_all boolean
---@return grapple.container_content
function ContainerContent:new(app, hook_fn, title_fn, show_all)
    return setmetatable({
        app = app,
        hook_fn = hook_fn,
        title_fn = title_fn,
        show_all = show_all,
    }, self)
end

---@return boolean
function ContainerContent:modifiable()
    return false
end

---Return the first editable cursor column for a line (0-indexed)
---@param _ string line
function ContainerContent:minimum_column(_)
    -- Assume: buffer is unmodifiable line contains two items: an id and path
    -- The id is in the form "/000" and followed by a space. Therefore the
    -- minimum column should be at 5 (0-indexed)
    return 5
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
    local current_scope, err = self.app:current_scope()
    if not current_scope then
        return nil, err
    end

    ---@param item_a grapple.tag_container_item
    ---@param item_b grapple.tag_container_item
    ---@return boolean
    local function by_loaded_then_id(item_a, item_b)
        local loaded_a = item_a.loaded and 1 or 0
        local loaded_b = item_b.loaded and 1 or 0
        if loaded_a ~= loaded_b then
            return loaded_a > loaded_b
        else
            return string.lower(item_a.id) < string.lower(item_b.id)
        end
    end

    local container_list = self.app.tag_manager:list()
    table.sort(container_list, by_loaded_then_id)

    local entities = {}

    for _, item in ipairs(container_list) do
        if not self.show_all and not item.loaded then
            goto continue
        end

        ---@class grapple.container_content.entity
        local entity = {
            id = item.id,
            container = item.container,
            loaded = item.loaded,
            current = item.id == current_scope.id,
        }

        table.insert(entities, entity)

        ::continue::
    end

    return entities, nil
end

---@param entity grapple.container_content.entity
---@param index integer
---@return grapple.window.entry
function ContainerContent:create_entry(entity, index)
    local container = entity.container

    -- A string representation of the index
    local id = string.format("/%03d", index)

    -- Don't try to modify IDs which are not paths, like "global"
    local container_id
    if Path.is_absolute(entity.id) then
        container_id = vim.fn.fnamemodify(entity.id, ":~")
    else
        container_id = entity.id
    end

    -- In compliance with "grapple" syntax
    local line = string.format("%s %s", id, container_id)
    local min_col = assert(string.find(line, "%s")) -- width of id

    -- Define line highlights for line and extmarks
    ---@type grapple.vim.highlight[]
    local highlights = {}

    local sign_highlight
    if self.app.settings.status and entity.current then
        sign_highlight = "GrappleCurrent"
    elseif not entity.loaded then
        sign_highlight = "GrappleHint"
    end

    local loaded_highlight
    if not entity.loaded then
        local col_start, col_end = assert(string.find(line, Util.escape(container_id)))
        loaded_highlight = {
            hl_group = "GrappleHint",
            line = index - 1,
            col_start = col_start - 1,
            col_end = col_end,
        }
    end

    highlights = vim.tbl_filter(Util.not_nil, {
        loaded_highlight,
    })

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

    local count_mark
    if container then
        local count = container:len()
        local count_text = count == 1 and "tag" or "tags"
        count_mark = {
            virt_text = { { string.format("[%d %s]", count, count_text) } },
            virt_text_pos = "eol",
        }
    end

    extmarks = vim.tbl_filter(Util.not_nil, { sign_mark, count_mark })
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
            id = entity.id,
        },

        line = line,
        index = index,
        min_col = min_col,

        ---@type grapple.vim.highlight[]
        highlights = highlights,

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
function ContainerContent:parse_line(line, original_entries)
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
function ContainerContent:perform(action, opts)
    opts = vim.tbl_extend("force", opts or {}, {
        show_all = self.show_all,
    })

    return action(opts)
end

return ContainerContent
