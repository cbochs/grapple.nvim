local Util = require("grapple.util")

---@class grapple.help_content
---@field buf_id integer buffer id of the current content window
local HelpContent = {}
HelpContent.__index = HelpContent

---@param buf_id integer
---@return grapple.help_content
function HelpContent:new(buf_id)
    return setmetatable({
        buf_id = buf_id,
    }, self)
end

---@return boolean
function HelpContent:modifiable()
    return false
end

---@param _ string
---@return integer min_col
function HelpContent:minimum_column(_)
    return 0
end

---@return string
function HelpContent:title()
    return "Help"
end

-- Blank interface implementations
function HelpContent:attach(_) end
function HelpContent:detach(_) end
function HelpContent:sync() end
function HelpContent:parse_line(_, _) end
function HelpContent:perform() end

---@return grapple.window.entity[] | nil, string? error
function HelpContent:entities()
    local app = require("grapple").app()

    ---@type grapple.vim.keymap[]
    local keymaps = vim.api.nvim_buf_get_keymap(self.buf_id, "n")

    -- Identify compressible quick-select keymaps
    local quick_selects = {}
    local index = 1
    for _, keymap in ipairs(keymaps) do
        if vim.tbl_contains(app.settings:quick_select(), keymap.lhs) then
            if quick_selects[index] == nil then
                quick_selects[index] = { keymap.lhs, keymap.lhs }
            elseif string.byte(quick_selects[index][2]) + 1 == string.byte(keymap.lhs) then
                quick_selects[index][2] = keymap.lhs
            else
                index = index + 1
                quick_selects[index] = { keymap.lhs, keymap.lhs }
            end
        end
    end

    -- Create base entities without padding
    local entities = {}
    for _, keymap in ipairs(keymaps) do
        -- Skip quick select keymaps
        if vim.tbl_contains(app.settings:quick_select(), keymap.lhs) then
            goto continue
        end

        -- Skip window close kaymaps
        if vim.tbl_contains({ "<c-c>", "<esc>" }, string.lower(keymap.lhs)) then
            goto continue
        end

        ---@class grapple.help_content.entity
        local entity = {
            lhs = keymap.lhs,
            desc = keymap.desc or "",
            padding = 0,
        }

        table.insert(entities, entity)

        ::continue::
    end

    -- Add compressed quick-select keymaps
    for _, quick_select in ipairs(quick_selects) do
        if quick_select[1] == quick_select[2] then
            table.insert(entities, {
                lhs = string.format("%s", quick_select[1]),
                desc = string.format("Quick select %s", quick_select[1]),
            })
        else
            table.insert(entities, {
                lhs = string.format("%s-%s", quick_select[1], quick_select[2]),
                desc = string.format("Quick select (%s-%s)", quick_select[1], quick_select[2]),
            })
        end
    end

    -- Determine lhs padding for left-alighment
    local padding = 0
    for _, keymap in ipairs(keymaps) do
        if #keymap.lhs > padding then
            padding = #keymap.lhs
        end
    end

    -- Add padding to entities
    for _, entity in ipairs(entities) do
        entity.padding = padding
    end

    local function by_desc(map_a, map_b)
        return map_a.desc < map_b.desc
    end

    table.sort(entities, by_desc)

    return entities
end

---@param entity grapple.help_content.entity
---@param index integer
---@return grapple.window.entry
function HelpContent:create_entry(entity, index)
    -- Line needs to be left-align padded beforehand
    -- Format: " {lhs}  {description}"
    local line_fmt = string.format(" %%-%ds  %%s", entity.padding)
    local line = string.format(line_fmt, entity.lhs, entity.desc)

    local col_start, col_end = assert(string.find(line, Util.escape(entity.lhs)))
    local lhs_highlight = {
        hl_group = "GrappleCurrent",
        line = index - 1,
        col_start = col_start - 1,
        col_end = col_end,
    }

    return {
        data = {},
        line = line,
        index = index,
        min_col = 0,
        highlights = { lhs_highlight },
        extmarks = {},
    }
end

return HelpContent
