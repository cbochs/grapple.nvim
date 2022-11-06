local config = require("grapple.config")
local _scope = require("grapple.scope")
local _tags = require("grapple.tags")

local M = {}

---@class Grapple.PopupItem
---@field text string
---@field deleted boolean
---@field select function

---@enum Grapple.Action
M.Action = {
    CLOSE = "close",
    DELETE = "delete",
    SELECT = "select",
    UNDO = "undo",
}

---@param buffer integer
---@param items Grapple.PopupItem[]
local function render(buffer, items)
    local lines = {}
    for _, item in pairs(items) do
        if not item.deleted then
            table.insert(lines, item.text)
        end
    end

    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
end

---@param buffer integer
---@param items Grapple.PopupItem[]
local function action_delete(buffer, items)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local index = cursor[1] -- [ line, col ] (1, 0)-based

    items[index].deleted = true
    render(buffer, items)
end

---@param buffer integer
---@param items Grapple.PopupItem[]
local function action_undo(buffer, items)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local index = cursor[1] -- [ line, col ] (1, 0)-based

    items[index].deleted = false
    render(buffer, items)
end

---@param window integer
local function action_close(window)
    if vim.api.nvim_win_is_valid(window) then
        vim.api.nvim_win_close(window, true)
    end
end

---@param window integer
---@param items Grapple.PopupItem[]
local function action_select(window, items)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local index = cursor[1] -- [ line, col ] (1, 0)-based
    action_close(window)
    items[index].select()
end

---@param tags Grapple.Tag[]
---@param scope Grapple.Scope
function M.open_tags(tags, scope)
    local scope_path = _scope.resolve(scope)
    local sanitized_scope_path = string.gsub(scope_path, "%p", "%%%1")

    ---@type Grapple.PopupItem[]
    local items = {}
    for _, tag in pairs(tags) do
        local relative_path = string.gsub(tag.file_path, sanitized_scope_path .. "/", "")
        table.insert(items, {
            title = relative_path,
            deleted = false,
            select = function()
                _tags.select(tag)
            end,
        })
    end

    local buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buffer, "bufhidden", "wipe")
    render(buffer, items)

    local window_options = vim.deepcopy(config.popup.options)
    local window = vim.api.nvim_open_win(buffer, false, window_options)

    for lhs, action in pairs(config.popup.keymaps) do
        if action == M.Action.CLOSE then
            vim.keymap.set("n", lhs, function()
                action_close(window)
            end, {})
        elseif action == M.Action.DELETE then
            vim.keymap.set("n", lhs, function()
                action_delete(buffer, items)
            end, {})
        elseif action == M.Action.SELECT then
            vim.keymap.set("n", lhs, function()
                action_select(window, items)
            end, {})
        elseif action == M.Action.UNDO then
            vim.keymap.set("n", lhs, function()
                action_undo(buffer, items)
            end, {})
        end
    end
end

return M
