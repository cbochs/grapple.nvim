local Path = require("plenary.path")
local log = require("grapple.log")
local popup = require("grapple.popup")
local scope = require("grapple.scope")
local tags = require("grapple.tags")
local state = require("grapple.state")

local M = {}

---@class Grapple.PopupTag
---@field key Grapple.TagKey
---@field tag Grapple.Tag

---@class Grapple.PopupPartialTag
---@field key Grapple.TagKey
---@field file_path string

---@param key Grapple.TagKey
---@param tag Grapple.Tag
---@return Grapple.PopupTag
local function into_popup_tag(key, tag)
    return {
        key = key,
        tag = tag,
    }
end

---@param popup_menu Grapple.Popup
---@param popup_tag Grapple.PopupTag
---@return string
local function serializer(popup_menu, popup_tag)
    local scope_path = scope.scope_path(popup_menu.scope)
    if vim.fn.isdirectory(scope_path) == 0 then
        scope_path = ""
    end

    local relative_path = Path:new(popup_tag.tag.file_path):make_relative(scope_path)
    local text = " [" .. popup_tag.key .. "] " .. tostring(relative_path)

    return text
end

---@param popup_menu Grapple.PopupMenu
---@param line string
---@return Grapple.PopupPartialTagTag
local function deserializer(popup_menu, line)
    if #line == 0 then
        return nil
    end

    local scope_path = scope.scope_path(popup_menu.scope)
    if vim.fn.isdirectory(scope_path) == 0 then
        scope_path = ""
    end

    local pattern = "%[(.*)%] +(.*)"
    local key, parsed_path = string.match(line, pattern)
    if key == nil or parsed_path == nil then
        log.warn(string.format("Unable to parse line into tag key. line: %s", line))
        return nil
    end

    local file_path
    if Path:new(parsed_path):is_absolute() then
        file_path = parsed_path
    else
        file_path = Path:new(scope_path) / parsed_path
    end

    ---@type Grapple.PopupTag
    local popup_tag = {
        key = tonumber(key) or key,
        file_path = tostring(file_path),
    }

    return popup_tag
end

---@param popup_menu Grapple.PopupMenu
local function resolve(popup_menu)
    ---@type Grapple.PopupPartialTag[]
    local parsed_partial_tags = popup.items(popup_menu)

    ---@type Grapple.PopupTag[]
    local before_popup_tags = popup_menu.items

    ---@type table<string, Grapple.PopupTag>
    local before_lookup = {}
    for _, before_tag in ipairs(before_popup_tags) do
        before_lookup[before_tag.tag.file_path] = before_tag
    end

    ---@type table<string, Grapple.PopupPartialTag>
    local after_lookup = {}
    for _, after_tag in ipairs(parsed_partial_tags) do
        after_lookup[after_tag.file_path] = after_tag
    end

    ---@type Grapple.PopupPartialTag[]
    local after_partial_tags = {}

    ---@type Grapple.StateChange[]
    local change_record = {}

    -- Delete tags that do not exist anymore
    for _, before_tag in ipairs(before_popup_tags) do
        local after_tag = after_lookup[before_tag.file_path]
        if after_tag ~= nil then
            table.insert(after_partial_tags, after_tag)
        else
            -- Assumptions:
            -- 1. the scope must exist for the popup menu to have been populated
            -- 2. the state should not have changed while the popup menu was open
            table.insert(change_record, state.actions.unset(before_tag.key))
        end
    end

    -- Update tags that now have a different key
    local index = 1
    for _, after_tag in ipairs(after_partial_tags) do
        local before_tag = before_lookup[after_tag.file_path]
        if after_tag.key ~= before_tag.key then
            local new_key = after_tag.key
            if type(after_tag.key) == "number" then
                new_key = index
                index = index + 1
            end
            table.insert(change_record, state.actions.move(before_tag.key, new_key))
        end
    end

    local scope_state = state.commit_raw(popup_menu.scope, change_record)

    return scope_state
end

---@param popup_menu Grapple.PopupMenu
local function action_close(popup_menu)
    popup.close(popup_menu)
end

---@param popup_menu Grapple.PopupMenu
local function action_select(popup_menu)
    local partial_tag = popup.current_selection(popup_menu)
    local scope_state = popup.close(popup_menu)

    local selected_key = state.reverse_lookup(scope_state, { file_path = partial_tag.file_path })
    local selected_tag = state.get_raw(scope_state, selected_key)

    if selected_tag ~= nil then
        tags.select(selected_tag)
    else
        log.debug(string.format("Unable to select tag from popup menu. tag: %s", vim.inspect(partial_tag)))
    end
end

---@param popup_menu Grapple.PopupMenu
local function action_select_split(popup_menu)
    vim.cmd("vsplit")
    action_select(popup_menu)
end

---@param popup_menu Grapple.PopupMenu
local function action_quickfix(popup_menu)
    local scope_state = popup.close(popup_menu)

    local quickfix_items = {}
    for key, tag in pairs(scope_state) do
        local quickfix_item = {
            filename = tag.file_path,
            lnum = tag.cursor and tag.cursor[1] or 1,
            col = tag.cursor and (tag.cursor[2] + 1) or 1,
            text = string.format(" [%s] ", key, tag.file_path),
        }
        table.insert(quickfix_items, quickfix_item)
    end

    vim.fn.setqflist(quickfix_items, "r")
    vim.fn.setqflist({}, "a", { title = popup_menu.scope })
    vim.api.nvim_cmd({ cmd = "copen" }, {})
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param window_options table
function M.open(scope_resolver, window_options)
    if vim.fn.has("nvim-0.9") == 1 then
        window_options.title = string.sub(scope.get(scope_resolver), 1, window_options.width - 6)
        window_options.title_pos = "center"
    end

    local actions = {
        { mode = "n", keymap = "q", action = action_close },
        { mode = "n", keymap = "<esc>", action = action_close },
        { mode = "n", keymap = "<cr>", action = action_select },
        { mode = "n", keymap = "<c-v>", action = action_select_split },
        { mode = "n", keymap = "<c-q>", action = action_quickfix },
    }

    popup.open(
        popup.create_window(window_options),
        popup.create_transformer(serializer, deserializer),
        resolve,
        actions,
        vim.tbl_map(into_popup_tag, tags.tags(scope_resolver)),
        scope.get(scope_resolver)
    )
end

return M
