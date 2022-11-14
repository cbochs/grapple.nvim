local popup = require("grapple.ui.popup")
local tags = require("grapple.tags")

local M = {}

---@return Grapple.Serializer<Grapple.Scope>
local function create_serializer()
    ---@param scope_path string
    ---@return string
    return function(scope_path)
        local scoped_tags = tags.tags(scope_path)
        local text = " [" .. #scoped_tags .. "] " .. scope_path
        return text
    end
end

---@return Grapple.Parser<Grapple.Scope>
local function create_parser()
    ---@param line string
    ---@return string
    return function(line)
        local pattern = "%] (.*)"
        local scope_path = string.match(line, pattern)
        return scope_path
    end
end

---@param popup_ Grapple.Popup
---@param parser Grapple.Parser<Grapple.Scope>
local function resolve(popup_, parser)
    ---@type string[]
    local lines = vim.api.nvim_buf_get_lines(popup_.buffer, 0, -1, false)

    ---@type string[]
    local scope_paths = vim.tbl_map(parser, lines)

    -- Determine which scopes have been modified and which were deleted
    ---@type table<string, boolean>
    local remaining_scopes = {}
    for _, scope_path in ipairs(scope_paths) do
        remaining_scopes[scope_path] = true
    end

    -- Reset scopes that were removed from the popup menu
    for _, scope_path in ipairs(tags.scopes()) do
        if not remaining_scopes[scope_path] then
            tags.reset(scope_path)
        end
    end
end

---@param popup_ Grapple.Popup
---@param parser Grapple.Parser<Grapple.Scope>
local function action_close(popup_, parser)
    return function()
        resolve(popup_, parser)
        popup.close(popup_)
    end
end

---@param window_options table
function M.open(window_options)
    if vim.fn.has("nvim-0.9") == 1 then
        window_options.title = "All Scopes"
        window_options.title_pos = "center"
    end

    local serializer = create_serializer()
    local parser = create_parser()

    local lines = vim.tbl_map(serializer, tags.scopes())
    local popup_ = popup.open(window_options)
    popup.update(popup_, lines)

    local close = action_close(popup_, parser)

    local keymap_options = { buffer = popup_.buffer, nowait = true }
    vim.keymap.set("n", "q", close, keymap_options)
    vim.keymap.set("n", "<esc>", close, keymap_options)
    popup.on_leave(popup_, close)
end

return M
