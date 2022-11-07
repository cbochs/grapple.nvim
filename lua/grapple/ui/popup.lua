local M = {}

---@class Grapple.Popup
---@field buffer integer
---@field window integer

---@param lines string[]
---@return Grapple.Popup
function M.open(lines, window_options)
    local buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buffer, "bufhidden", "wipe")
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)

    window_options.row = math.floor(((vim.o.lines - window_options.height) / 2) - 1)
    window_options.col = math.floor((vim.o.columns - window_options.width) / 2)

    local window = vim.api.nvim_open_win(buffer, true, window_options)

    local popup = {
        buffer = buffer,
        window = window,
    }

    return popup
end

---@param popup Grapple.Popup
---@param close function
function M.on_leave(popup, close)
    vim.api.nvim_create_augroup("GrapplePopup", { clear = true })
    vim.api.nvim_create_autocmd({ "WinLeave" }, {
        group = "GrapplePopup",
        buffer = popup.buffer,
        callback = close,
    })
end

---@param popup Grapple.Popup
function M.close(popup)
    if vim.api.nvim_win_is_valid(popup.window) then
        vim.api.nvim_win_close(popup.window, true)
    end
end

return M
