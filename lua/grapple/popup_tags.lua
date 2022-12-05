local Path = require("plenary.path")
local log = require("grapple.log")
local popup = require("grapple.popup")
local scope = require("grapple.scope")
local tags = require("grapple.tags")
local state = require("grapple.state")
local quickfix = require("grapple.quickfix")

local popup_tags = {}

---@class Grapple.PopupTagState
---@field items Grapple.FullTag[]
---@field scope Grapple.Scope

---@param scope_resolver Grapple.ScopeResolverLike
---@return Grapple.PopupTagState
function popup_tags.initial_state(scope_resolver)
    local scope_ = scope.get(scope_resolver)
    return {
        items = state.with_keys_raw(state.scope_raw(scope_)),
        scope = scope_,
    }
end

---@param popup_menu Grapple.PopupMenu
---@param full_tag Grapple.FullTag
---@return string
function popup_tags.serialize(popup_menu, full_tag)
    local scope_path = scope.scope_path(popup_menu.state.scope)
    local file_path = Path:new(full_tag.file_path)

    if vim.fn.isdirectory(scope_path) == 1 then
        file_path = file_path:make_relative(scope_path)
    end

    local text = " [" .. full_tag.key .. "] " .. tostring(file_path)

    return text
end

---@param popup_menu Grapple.PopupMenu
---@param line string
---@return Grapple.PartialTag
function popup_tags.deserialize(popup_menu, line)
    if #line == 0 then
        return nil
    end

    local scope_path = scope.scope_path(popup_menu.state.scope)
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

    ---@type Grapple.PartialTag
    local partial_tag = {
        key = tonumber(key) or key,
        file_path = tostring(file_path),
    }

    return partial_tag
end

---@param popup_menu Grapple.PopupMenu
---@return Grapple.PopupTag[]
function popup_tags.resolve(popup_menu)
    ---@type Grapple.PopupTag[]
    local original_tags = popup_tags.state.items

    ---@type Grapple.PartialTag[]
    local modified_tags = popup.items(popup_menu)

    local differences = popup_tags.diff(original_tags, modified_tags)
    local scope_state = state.commit_raw(popup_menu.scope, differences)

    return scope_state
end

---@param original_tags Grapple.FullTag[]
---@param modified_tags Grapple.PartialTag[]
---@return Grapple.StateAction[]
function popup_tags.diff(original_tags, modified_tags)
    local index = 1
    for _, after_tag in ipairs(modified_tags) do
        if type(after_tag.key) == "number" then
            after_tag.key = index
            index = index + 1
        end
    end

    ---@type table<string, Grapple.FullTag>
    local before_lookup = {}
    for _, before_tag in ipairs(original_tags) do
        before_lookup[before_tag.file_path] = before_tag
    end

    ---@type table<string, Grapple.PartialTag>
    local after_lookup = {}
    for _, after_tag in ipairs(modified_tags) do
        after_lookup[after_tag.file_path] = after_tag
    end

    ---@type Grapple.PartialTag[]
    local after_partial_tags = {}

    ---@type Grapple.StateChange[]
    local change_record = {}

    -- Delete tags that do not exist anymore
    for _, before_tag in ipairs(original_tags) do
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
    for _, after_tag in ipairs(after_partial_tags) do
        local before_tag = before_lookup[after_tag.file_path]
        if after_tag.key ~= before_tag.key then
            table.insert(change_record, state.actions.move(before_tag.key, after_tag.key))
        end
    end

    return change_record
end

popup_tags.actions = {}

---@param popup_menu Grapple.PopupMenu
function popup_tags.actions.close(popup_menu)
    popup.close(popup_menu)
end

---@param popup_menu Grapple.PopupMenu
function popup_tags.actions.select(popup_menu)
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
function popup_tags.actions.select_vsplit(popup_menu)
    vim.cmd("vsplit")
    popup_tags.actions.select(popup_menu)
end

---@param popup_menu Grapple.PopupMenu
function popup_tags.actions.quickfix(popup_menu)
    local scope_state = popup.close(popup_menu)
    local full_tags = state.with_keys_raw(scope_state)
    quickfix.send(popup_menu.scope, full_tags, tags.quickfixer)
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param window_options table
function popup_tags.open(scope_resolver, window_options)
    if vim.fn.has("nvim-0.9") == 1 then
        window_options.title = string.sub(scope.get(scope_resolver), 1, window_options.width - 6)
        window_options.title_pos = "center"
    end

    local actions = {
        { mode = "n", keymap = "q", action = popup_tags.actions.close },
        { mode = "n", keymap = "<esc>", action = popup_tags.actions.close },
        { mode = "n", keymap = "<cr>", action = popup_tags.actions.select },
        { mode = "n", keymap = "<c-v>", action = popup_tags.actions.select_split },
        { mode = "n", keymap = "<c-q>", action = popup_tags.actions.quickfix },
    }

    local scope_ = scope.get(scope_resolver)
    local scope_state = state.scope_raw(scope_)
    local items = state.with_keys_raw(scope_state)

    popup.open(
        popup.create_window(window_options),
        popup.create_transformer(popup_tags.serialize, popup_tags.deserialize),
        popup_tags.resolve,
        actions,
        items,
        scope_
    )
end

return popup_tags
