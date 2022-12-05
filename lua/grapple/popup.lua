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
---@field keymap string
---@field action Grapple.PopupFunction

---@generic T
---@class Grapple.PopupHandler<T>
---@field serialize Grapple.PopupSerializer<T>
---@field deserialize Grapple.PopupDeserializer<T>
---@field resolve Grapple.PopupFunction
---@field actions Grapple.PopupAction[]

---@generic T
---@class Grapple.PopupState
---@field items T[]

---@generic T
---@class Grapple.PopupMenu<T>
---@field popup Grapple.Popup
---@field handler Grapple.PopupHandler<T>
---@field state Grapple.PopupState<T>

---@generic T
---@param window_options Grapple.WindowOptions
---@param popup_handler Grapple.PopupHandler
---@return Grapple.PopupMenu
function popup.open(window_options, popup_handler, popup_state)
    local popup_menu = {
        popup = popup.create_window(window_options),
        handler = popup_handler,
        state = popup_state,
    }

    vim.api.nvim_create_augroup("GrapplePopup", { clear = true })
    vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
        group = "GrapplePopup",
        buffer = popup_menu.popup.buffer,
        callback = function()
            popup.close(popup_menu)
        end,
    })

    for _, action in ipairs(popup_menu.handler.actions) do
        vim.keymap.set(action.mode, action.keymap, function()
            action.action(popup_menu)
        end, { buffer = popup_menu.popup.buffer })
    end

    popup.draw(popup_menu)

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
    vim.api.nvim_buf_set_option(buffer, "filetype", "grapple")
    vim.api.nvim_buf_set_option(buffer, "bufhidden", "wipe")

    window_options.row = math.floor(((vim.o.lines - window_options.height) / 2) - 1)
    window_options.col = math.floor((vim.o.columns - window_options.width) / 2)

    local window = vim.api.nvim_open_win(buffer, true, window_options)

    local popup_ = {
        buffer = buffer,
        window = window,
        options = window_options,
    }

    return popup_
end

---@param popup_menu Grapple.PopupMenu
function popup.draw(popup_menu)
    local lines = vim.tbl_map(function(item)
        popup_menu.handler.serialize(popup_menu, item)
    end, popup_menu.state.items)
    vim.api.nvim_buf_set_lines(popup_menu.popup.buffer, 0, -1, false, lines)
end

---@param popup_menu Grapple.PopupMenu
---@param new_popup_state Grapple.PopupState
function popup.update(popup_menu, new_popup_state)
    popup_menu.state = new_popup_state
    popup.draw(popup_menu)
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
        popup_menu.handler.deserialize(popup_menu, line)
    end, lines)
    return parsed_items
end

---@param popup_menu Grapple.PopupMenu<T>
---@return any
function popup.close(popup_menu)
    local popup_resolution = popup_menu.resolve(popup_menu)
    if vim.api.nvim_win_is_valid(popup_menu.popup.window) then
        vim.api.nvim_win_close(popup_menu.popup.window, true)
    end
    return popup_resolution
end

return popup
