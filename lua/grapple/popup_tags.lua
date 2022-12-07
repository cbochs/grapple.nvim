local Path = require("plenary.path")
local log = require("grapple.log")
local popup = require("grapple.popup")
local scope = require("grapple.scope")
local state = require("grapple.state")
local tags = require("grapple.tags")

local popup_tags = {}

---@class Grapple.PopupTagState
---@field scope Grapple.Scope

popup_tags.handler = {}

---@param popup_menu Grapple.PopupMenu
---@param full_tag Grapple.FullTag
---@return string
function popup_tags.handler.serialize(popup_menu, full_tag)
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
function popup_tags.handler.deserialize(popup_menu, line)
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
function popup_tags.handler.resolve(popup_menu)
    ---@type Grapple.PopupTag[]
    local original_tags = popup_menu.items

    ---@type Grapple.PartialTag[]
    local modified_tags = popup.items(popup_menu)

    popup_tags.resolve_differences(popup_menu.state.scope, original_tags, modified_tags)
end

popup_tags.actions = {}

---@param popup_menu Grapple.PopupMenu
function popup_tags.actions.close(popup_menu)
    popup.close(popup_menu)
end

---@param popup_menu Grapple.PopupMenu
function popup_tags.actions.select(popup_menu)
    local partial_tag = popup.current_selection(popup_menu)

    popup.close(popup_menu)

    local selected_key = state.key(popup_menu.state.scope, { file_path = partial_tag.file_path })
    local selected_tag = state.get(popup_menu.state.scope, selected_key)

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
    popup.close(popup_menu)
    tags.quickfix(popup_menu.state.scope)
end

---@param scope_ Grapple.Scope
---@param original_tags Grapple.FullTag[]
---@param modified_tags Grapple.PartialTag[]
---@return Grapple.StateAction[]
function popup_tags.resolve_differences(scope_, original_tags, modified_tags)
    -- Use the line number as the index for numbered tags
    local index = 1
    for i = 1, #modified_tags do
        if type(modified_tags[i].key) == "number" then
            modified_tags[i].key = index
            index = index + 1
        end
    end

    ---@type table<string, Grapple.PartialTag>
    local after_lookup = {}
    for _, after_tag in ipairs(modified_tags) do
        after_lookup[after_tag.file_path] = after_tag
    end

    ---@type Grapple.PartialTag[]
    local remaining_tags = {}

    ---@type Grapple.PartialTag[]
    local deleted_tags = {}

    -- Determine which tags are remaining and which were deleted
    for _, before_tag in ipairs(original_tags) do
        local after_tag = after_lookup[before_tag.file_path]
        if after_tag ~= nil then
            if after_tag.key ~= before_tag.key then
                table.insert(remaining_tags, after_tag)
            end
        else
            table.insert(deleted_tags, before_tag)
        end
    end

    -- Delete tags that do not exist anymore
    for _, deleted_tag in ipairs(deleted_tags) do
        -- Assumptions:
        -- 1. the scope must exist for the popup menu to have been populated
        -- 2. the state should not have changed while the popup menu was open
        tags.untag(scope_, { key = deleted_tag.key })
        log.debug(string.format("Tag not found in popup, deleting. tag %s", vim.inspect(deleted_tag)))
    end

    -- Update tags that may now have a different key
    for _, remaining_tag in ipairs(remaining_tags) do
        tags.tag(scope_, {
            file_path = remaining_tag.file_path,
            key = remaining_tag.key,
        })
    end
end

return popup_tags
