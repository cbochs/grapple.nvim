local _scope = require("grapple.scope")
local _tags = require("grapple.tags")
local log = require("grapple.log")
local popup = require("grapple.ui.popup")

local M = {}

---@param scope Grapple.Scope
---@return { tags: Grapple.TagTable, lines: string[] }
local function itemize(scope)
    local scoped_tags = _tags.tags(scope)
    local scope_path = _scope.resolve(scope)
    local sanitized_scope_path = string.gsub(scope_path, "%p", "%%%1")

    local lines = {}
    for key, tag in pairs(scoped_tags) do
        local relative_path = string.gsub(tag.file_path, sanitized_scope_path .. "/", "")
        local text = " [" .. key .. "] " .. relative_path
        table.insert(lines, text)
    end

    return {
        tags = scoped_tags,
        lines = lines,
    }
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
---@param tags Grapple.TagTable
---@param _popup Grapple.Popup
local function resolve(scope, tags, _popup)
    local lines = vim.api.nvim_buf_get_lines(_popup.buffer, 0, -1, false)
    local remaining_keys = {}
    for _, line in ipairs(lines) do
        local tag_key = parse(line)
        if tag_key ~= nil then
            remaining_keys[tag_key] = true
        end
    end
    for key, tag in pairs(tags) do
        if not remaining_keys[key] then
            _tags.untag(scope, { file_path = tag.file_path })
        end
    end
end

---@param scope Grapple.Scope
---@param tags Grapple.TagTable
---@param _popup Grapple.Popup
---@return function
local function action_close(scope, tags, _popup)
    return function()
        resolve(scope, tags, _popup)
        popup.close(_popup)
    end
end

---@param scope Grapple.Scope
---@param tags Grapple.TagTable
---@param _popup Grapple.Popup
local function action_select(scope, tags, _popup)
    return function()
        local current_line = vim.api.nvim_get_current_line()
        local tag_key = parse(current_line)
        local tag = _tags.find(scope, { key = tag_key or "" })

        resolve(scope, tags, _popup)
        popup.close(_popup)

        if tag ~= nil then
            _tags.select(tag)
        end
    end
end

---@param scope Grapple.Scope
---@param window_options table
function M.open(scope, window_options)
    if vim.fn.has("nvim-0.9") == 1 then
        window_options.title = _scope.resolve(scope)
        window_options.title_pos = "center"
    end

    local items = itemize(scope)
    local _popup = popup.open(items.lines, window_options)

    local close = action_close(scope, items.tags, _popup)
    local select = action_select(scope, items.tags, _popup)

    popup.on_leave(_popup, close)

    local kopts = { buffer = _popup.buffer, nowait = true }
    vim.keymap.set("n", "q", "<esc>", vim.tbl_extend("keep", { remap = true }, kopts))
    vim.keymap.set("n", "<esc>", close, kopts)
    vim.keymap.set("n", "<cr>", select, kopts)
end

return M
