local M = {}

---@class Grapple.Popup
---@field buffer integer
---@field window integer

---@generic T
---@alias Grapple.Serializer fun(item: T): string

---@generic T
---@alias Grapple.Parser fun(line: string): T

---@param lines string[]
---@return Grapple.Popup
function M.open(window_options)
    local buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buffer, "filetype", "grapple")
    vim.api.nvim_buf_set_option(buffer, "bufhidden", "wipe")

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
---@param lines string[]
function M.update(popup, lines)
    vim.api.nvim_buf_set_lines(popup.buffer, 0, -1, false, lines)
end

---@param popup Grapple.Popup
---@param close function
function M.on_leave(popup, close)
    vim.api.nvim_create_augroup("GrapplePopup", { clear = true })
    vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
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
