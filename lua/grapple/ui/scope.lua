local popup = require("grapple.ui.popup")
local tags = require("grapple.tags")

local M = {}

---@return string[]
local function serialize()
    local scopes = tags.scopes()
    table.sort(scopes)

    local lines = {}
    for _, scope in ipairs(scopes) do
        local scoped_tags = M.tags(scope)
        local text = " [" .. #scoped_tags .. "] " .. scope
        table.insert(lines, text)
    end

    return lines
end

---@param line string
---@return string | nil
local function parse(line)
    local start, _end = string.find(line, "%] .*$")
    if not start or not _end then
        return nil
    end
    local parsed_scope = string.sub(line, start + 2, _end)
    return parsed_scope
end

---@param _popup Grapple.Popup
---@return function
local function action_close(_popup)
    return function()
        local lines = vim.api.nvim_buf_get_lines(_popup.buffer, 0, -1, false)
        popup.close(_popup)

        local remaining_scopes = {}
        for _, line in ipairs(lines) do
            table.insert(remaining_scopes, parse(line))
        end

        tags.resolve_scopes(remaining_scopes)
    end
end

---@param window_options table
function M.open(window_options)
    local lines = serialize()
    local _popup = popup.open(lines, window_options)
    local close = action_close(_popup)

    vim.keymap.set("n", "q", close, { buffer = _popup.buffer })
    vim.keymap.set("n", "<esc>", close, { buffer = _popup.buffer })
end

return M
