local log = require("grapple.log")

local popup = {}

---@class Grapple.Popup
---@field buffer number
---@field window number
---@field options Grapple.WindowOptions

---@generic T
---@alias Grapple.PopupSerializer fun(popup_menu: Grapple.PopupMenu, item: T): string

---@generic T
---@alias Grapple.PopupDeserializer fun(popup_menu: Grapple.PopupMenu, line: string): T

---@alias Grapple.PopupFunction fun(popup_menu: Grapple.PopupMenu)

---@class Grapple.PopupAction
---@field mode string | string[]
---@field key string
---@field action Grapple.PopupFunction

---@generic T
---@class Grapple.PopupHandler<T>
---@field serialize Grapple.PopupSerializer<T>
---@field deserialize Grapple.PopupDeserializer<T>
---@field resolve? Grapple.PopupFunction

---@alias Grapple.PopupState any

---@generic T
---@class Grapple.PopupMenu<T>
---@field popup Grapple.Popup
---@field handler Grapple.PopupHandler<T>
---@field state Grapple.PopupState
---@field items T[]

local current_popup = nil

---@return Grapple.PopupMenu
function popup.current()
    if current_popup == nil then
        log.warn("No popup menu is currently open")
    end
    return current_popup
end

---@generic T
---@param window_options Grapple.WindowOptions
---@param popup_handler Grapple.PopupHandler
---@param popup_state Grapple.PopupState
---@return Grapple.PopupMenu
function popup.open(window_options, popup_handler, popup_state)
    local popup_menu = {
        popup = popup.create_window(window_options),
        handler = popup_handler,
        state = popup_state,
        items = {},
    }

    vim.api.nvim_create_augroup("GrapplePopup", { clear = true })
    vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
        group = "GrapplePopup",
        buffer = popup_menu.popup.buffer,
        callback = function()
            popup.close(popup_menu)
        end,
    })
    vim.api.nvim_create_autocmd({ "VimResized" }, {
        group = "GrapplePopup",
        callback = function()
            popup_menu.popup.options.row = math.floor(((vim.o.lines - window_options.height) / 2) - 1)
            popup_menu.popup.options.col = math.floor((vim.o.columns - window_options.width) / 2)
            if not vim.api.nvim_win_is_valid(popup_menu.popup.window) then
                return
            end
            vim.api.nvim_win_set_config(popup_menu.popup.window, popup_menu.popup.options)
        end,
    })

    current_popup = popup_menu

    return popup_menu
end

---@param window_options Grapple.WindowOptions
---@return Grapple.Popup
function popup.create_window(window_options)
    if window_options.title ~= nil then
        window_options.title = string.sub(window_options.title, 1, window_options.width - 6)
        window_options.title_pos = "center"
    end

    local buffer = vim.api.nvim_create_buf(false, true)

    window_options.row = math.floor(((vim.o.lines - window_options.height) / 2) - 1)
    window_options.col = math.floor((vim.o.columns - window_options.width) / 2)

    local window = vim.api.nvim_open_win(buffer, true, window_options)

    vim.api.nvim_buf_set_option(buffer, "filetype", "grapple")
    vim.api.nvim_buf_set_option(buffer, "bufhidden", "wipe")

    local popup_ = {
        buffer = buffer,
        window = window,
        options = window_options,
    }

    return popup_
end

---@param popup_menu Grapple.PopupMenu
function popup.render(popup_menu)
    local lines = vim.tbl_map(function(item)
        return popup_menu.handler.serialize(popup_menu, item)
    end, popup_menu.items)
    vim.api.nvim_buf_set_lines(popup_menu.popup.buffer, 0, -1, false, lines)
end

---@param popup_menu Grapple.PopupMenu
---@param items table
function popup.update(popup_menu, items)
    popup_menu.items = items
    popup.render(popup_menu)
end

---@param popup_menu Grapple.PopupMenu
---@param popup_keymaps Grapple.PopupAction[]
function popup.keymap(popup_menu, popup_keymaps)
    for _, keymap in ipairs(popup_keymaps) do
        vim.keymap.set(keymap.mode, keymap.key, function()
            keymap.action(popup_menu)
        end, { buffer = popup_menu.popup.buffer })
    end
end

---@generic T
---@param popup_menu Grapple.PopupMenu<T>
---@return T
function popup.current_selection(popup_menu)
    local current_line = vim.api.nvim_get_current_line()
    local selection = popup_menu.handler.deserialize(popup_menu, current_line)
    return selection
end

---@generic T
---@param popup_menu Grapple.PopupMenu<T>
---@return T[]
function popup.items(popup_menu)
    local lines = vim.api.nvim_buf_get_lines(popup_menu.popup.buffer, 0, -1, false)
    local parsed_items = vim.tbl_map(function(line)
        return popup_menu.handler.deserialize(popup_menu, line)
    end, lines)
    return parsed_items
end

---@generic T
---@param popup_menu Grapple.PopupMenu<T>
function popup.close(popup_menu)
    if popup_menu.handler.resolve ~= nil then
        local ok, _ = pcall(popup_menu.handler.resolve, popup_menu)
        if not ok then
            log.warn("Failed to resolve popup menu before closing")
        end
    end
    if vim.api.nvim_win_is_valid(popup_menu.popup.window) then
        vim.api.nvim_win_close(popup_menu.popup.window, true)
    end
    current_popup = nil
end

return popup
