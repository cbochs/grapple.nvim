local popup = require("grapple.ui.popup")
local tags = require("grapple.tags")

local M = {}

---@return { scopes: string[], lines: string[] }
local function itemize()
    local scopes = tags.scopes()
    table.sort(scopes)

    local lines = {}
    for _, scope in ipairs(scopes) do
        local scoped_tags = tags.tags(scope)
        local text = " [" .. #scoped_tags .. "] " .. scope
        table.insert(lines, text)
    end

    return {
        scopes = scopes,
        lines = lines,
    }
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
---@param scopes string[]
---@return function
local function action_close(_popup, scopes)
    return function()
        local lines = vim.api.nvim_buf_get_lines(_popup.buffer, 0, -1, false)
        popup.close(_popup)

        local remaining_scopes = {}
        for _, line in ipairs(lines) do
            local scope = parse(line)
            if scope ~= nil then
                remaining_scopes[scope] = true
            end
        end
        for _, scope in ipairs(scopes) do
            if not remaining_scopes[scope] then
                tags.reset(scope)
            end
        end
    end
end

---@param opts Grapple.PopupConfig
function M.open(opts)
    local winopts = opts.winopts
    if vim.fn.has("nvim-0.9") == 1 then
        winopts.title = "All Scopes"
        winopts.title_pos = "center"
    end

    local items = itemize()
    local _popup = popup.open(items.lines, winopts)
    local close = action_close(_popup, items.scopes)

    popup.on_leave(_popup, close)
    vim.keymap.set("n", "q", close, { buffer = _popup.buffer })
    vim.keymap.set("n", "<esc>", close, { buffer = _popup.buffer })
end

return M
