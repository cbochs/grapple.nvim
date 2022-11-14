local log = require("grapple.log")
local popup = require("grapple.ui.popup")
local scope = require("grapple.scope")
local tags = require("grapple.tags")

local M = {}

---Ingested by the serializer
---@class Grapple.PopupTag
---@field key Grapple.TagKey
---@field tag Grapple.Tag

---Created by the parser
---@class Grapple.PartialTag
---@field file_path string
---@field key Grapple.TagKey

---@param key Grapple.TagKey
---@param tag Grapple.Tag
---@return Grapple.PopupTag
local function into_popup_tag(key, tag)
    return {
        key = key,
        tag = tag,
    }
end

---@param scope_ Grapple.Scope
---@return Grapple.Serializer<Grapple.PopupTag>
local function create_serializer(scope_)
    local scope_path = scope.resolve(scope_)
    scope_path = string.gsub(scope_path, "%p", "%%%1")

    ---@param popup_tag Grapple.PopupTag
    ---@return string
    return function(popup_tag)
        local relative_path = string.gsub(popup_tag.tag.file_path, scope_path .. "/", "")
        local text = " [" .. popup_tag.key .. "] " .. relative_path
        return text
    end
end

---@param scope_ Grapple.Scope
---@return Grapple.Parser<Grapple.PartialTag>
local function create_parser(scope_)
    local scope_path = scope.resolve(scope_)

    ---@param line string
    ---@return Grapple.PartialTag
    return function(line)
        if #line == 0 then
            return nil
        end

        local pattern = "%[(.*)%] +(.*)"
        local key, relative_path = string.match(line, pattern)
        if key == nil or relative_path == nil then
            log.warn(("Unable to parse line into tag key. Line: %s"):format(line))
            return nil
        end

        local file_path
        if string.sub(relative_path, 1, 1) == "/" then
            file_path = relative_path
        else
            file_path = scope_path .. "/" .. relative_path
        end

        ---@type Grapple.PartialTag
        local partial_tag = {
            file_path = file_path,
            key = tonumber(key) or key,
        }

        return partial_tag
    end
end

---@param scope_ Grapple.Scope
---@param popup_ Grapple.Popup
---@param parser Grapple.Parser<Grapple.PartialTag>
local function resolve(scope_, popup_, parser)
    ---@type string[]
    local lines = vim.api.nvim_buf_get_lines(popup_.buffer, 0, -1, false)

    ---@type Grapple.PartialTag[]
    local partial_tags = vim.tbl_map(parser, lines)

    -- Use the line number as the index for numbered tags
    local index = 1
    for i = 1, #partial_tags do
        if type(partial_tags[i].key) == "number" then
            partial_tags[i].key = index
            index = index + 1
        end
    end

    ---@type table<string, boolean>
    local remaining_tags = {}

    ---@type Grapple.PartialTag[]
    local modified_tags = {}

    -- Determine which tags have been modified and which were deleted
    for _, partial_tag in ipairs(partial_tags) do
        local key = tags.key(scope_, { file_path = partial_tag.file_path })
        if key ~= nil then
            if partial_tag.key ~= key then
                table.insert(modified_tags, partial_tag)
            end
            remaining_tags[key] = true
        else
            log.warn("Unable to find tag key for parsed file path. Path: " .. partial_tag.file_path)
        end
    end

    -- Delete tags that do not exist anymore
    for _, key in ipairs(tags.keys(scope_)) do
        if not remaining_tags[key] then
            tags.untag(scope_, { key = key })
        end
    end

    -- Update tags that now have a different key
    for _, partial_tag in ipairs(modified_tags) do
        tags.tag(scope_, { file_path = partial_tag.file_path, key = partial_tag.key })
    end

    -- Fill any "holes" that were made from deletion and updating
    tags.reorder(scope_)
end

---@param scope_ Grapple.Scope
---@param popup_ Grapple.Popup
---@param parser Grapple.Parser<Grapple.PartialTag>
local function action_close(scope_, popup_, parser)
    return function()
        resolve(scope_, popup_, parser)
        popup.close(popup_)
    end
end

---@param scope_ Grapple.Scope
---@param popup_ Grapple.Popup
---@param parser Grapple.Parser<Grapple.PartialTag>
local function action_select(scope_, popup_, parser)
    return function()
        local current_line = vim.api.nvim_get_current_line()
        local partial_tag = parser(current_line)
        action_close(scope_, popup_, parser)()

        local selected_tag = tags.find(scope_, { file_path = partial_tag.file_path })
        if selected_tag ~= nil then
            tags.select(selected_tag)
        end
    end
end

---@param scope_ Grapple.Scope
---@param window_options table
function M.open(scope_, window_options)
    if vim.fn.has("nvim-0.9") == 1 then
        window_options.title = scope.resolve(scope_)
        window_options.title_pos = "center"
    end

    local serializer = create_serializer(scope_)
    local parser = create_parser(scope_)

    local popup_tags = {}
    for key, tag in pairs(tags.tags(scope_)) do
        table.insert(popup_tags, into_popup_tag(key, tag))
    end

    local lines = vim.tbl_map(serializer, popup_tags)
    local popup_ = popup.open(window_options)
    popup.update(popup_, lines)

    local close = action_close(scope_, popup_, parser)
    local select = action_select(scope_, popup_, parser)

    local keymap_options = { buffer = popup_.buffer, nowait = true }
    vim.keymap.set("n", "q", close, keymap_options)
    vim.keymap.set("n", "<esc>", close, keymap_options)
    vim.keymap.set("n", "<cr>", select, keymap_options)
    popup.on_leave(popup_, close)
end

return M
