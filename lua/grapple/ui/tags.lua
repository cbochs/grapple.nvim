local _scope = require("grapple.scope")
local log = require("grapple.log")
local popup = require("grapple.ui.popup")
local tags = require("grapple.tags")

local M = {}

---@param scope Grapple.Scope
---@return string[]
local function serialize(scope)
    local scoped_keys = tags.keys(scope)
    local scope_path = _scope.resolve(scope)
    local sanitized_scope_path = string.gsub(scope_path, "%p", "%%%1")

    local lines = {}
    for _, key in ipairs(scoped_keys) do
        local tag = tags.find(scope, { key = key })
        if tag ~= nil then
            local relative_path = string.gsub(tag.file_path, sanitized_scope_path .. "/", "")
            local text = " [" .. key .. "] " .. relative_path
            table.insert(lines, text)
        end
    end
    return lines
end

---@param line string
---@return Grapple.TagKey | nil
local function parse(line)
    local start, _end = string.find(line, "%[.*%]")
    if not start or not _end then
        log.warn("Unable to parse line into tag key. Line: " .. line)
        return nil
    end
    local parsed_key = string.sub(line, start + 1, _end - 1)
    return tonumber(parsed_key) or parsed_key
end

---@param scope Grapple.Scope
---@param _popup Grapple.Popup
---@return function
local function action_close(scope, _popup)
    return function()
        local lines = vim.api.nvim_buf_get_lines(_popup.buffer, 0, -1, false)
        popup.close(_popup)

        local remaining_keys = {}
        for _, line in ipairs(lines) do
            table.insert(remaining_keys, parse(line))
        end

        tags.resolve_tags(scope, remaining_keys)
    end
end

---@param scope Grapple.Scope
---@param close function
local function action_select(scope, close)
    return function()
        local line = vim.api.nvim_get_current_line()
        close()

        local tag_key = parse(line)
        if tag_key == nil then
            return
        end

        local tag = tags.find(scope, { key = tag_key })
        if tag ~= nil then
            tags.select(tag)
        end
    end
end

---@param scope Grapple.Scope
---@param window_options table
function M.open(scope, window_options)
    local lines = serialize(scope)
    local _popup = popup.open(lines, window_options)

    local close = action_close(scope, _popup)
    local select = action_select(scope, close)

    vim.keymap.set("n", "q", close, { buffer = _popup.buffer })
    vim.keymap.set("n", "<esc>", close, { buffer = _popup.buffer })
    vim.keymap.set("n", "<cr>", select, { buffer = _popup.buffer })
end

return M
