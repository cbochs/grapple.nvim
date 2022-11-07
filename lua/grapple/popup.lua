local tags = require("grapple.tags")
local config = require("grapple.config")

local M = {}

---@param scope Grapple.Scope
function M.open_tags(scope)
    local buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buffer, "bufhidden", "wipe")

    local lines = tags.serialize(scope)
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)

    local window_options = vim.deepcopy(config.popup.options)
    window_options.row = math.floor(((vim.o.lines - window_options.height) / 2) - 1)
    window_options.col = math.floor((vim.o.columns - window_options.width) / 2)

    local window = vim.api.nvim_open_win(buffer, true, window_options)

    local function close()
        local remaining_lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
        if vim.api.nvim_win_is_valid(window) then
            vim.api.nvim_win_close(window, true)
        end
        tags.resolve_lines(scope, remaining_lines)
    end

    local function select()
        local line = vim.api.nvim_get_current_line()
        close()

        local tag_key = tags.parse_line(line)
        if tag_key == nil then
            return
        end

        local tag = tags.find(scope, { key = tag_key })
        if tag ~= nil then
            tags.select(tag)
        end
    end

    vim.keymap.set("n", "q", close, { buffer = buffer })
    vim.keymap.set("n", "<esc>", close, { buffer = buffer })
    vim.keymap.set("n", "<cr>", select, { buffer = buffer })
end

return M
