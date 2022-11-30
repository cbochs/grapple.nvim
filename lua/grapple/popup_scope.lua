local popup = require("grapple.popup")
local state = require("grapple.state")

local M = {}

---@return Grapple.Serializer<Grapple.ScopePair>
local function create_serializer()
    ---@param scope Grapple.Scope
    ---@return string
    return function(scope)
        local scope_resolver = state.resolver(scope)
        local text = " [" .. state.count(scope_resolver) .. "]" .. scope
        return text
    end
end

---@return Grapple.Parser<Grapple.Scope>
local function create_parser()
    ---@param line string
    ---@return Grapple.Scope
    return function(line)
        local pattern = "%] (.*)"
        local scope = string.match(line, pattern)
        return scope
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
    for _, scope in ipairs(scope_paths) do
        remaining_scopes[scope] = true
    end

    -- Reset scopes that were removed from the popup menu
    for _, scope in ipairs(state.scopes()) do
        if not remaining_scopes[scope] then
            local scope_resolver = state.resolver(scope)
            state.reset(scope_resolver)
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
        window_options.title = "Loaded Scopes"
        window_options.title_pos = "center"
    end

    local serializer = create_serializer()
    local parser = create_parser()

    local lines = vim.tbl_map(serializer, state.scopes())
    local popup_ = popup.open(window_options)
    popup.update(popup_, lines)

    local close = action_close(popup_, parser)

    local keymap_options = { buffer = popup_.buffer, nowait = true }
    vim.keymap.set("n", "q", close, keymap_options)
    vim.keymap.set("n", "<esc>", close, keymap_options)
    popup.on_leave(popup_, close)
end

return M
