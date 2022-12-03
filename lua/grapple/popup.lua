local popup = {}

---@class Grapple.Popup
---@field buffer number
---@field window number

---@generic T
---@alias Grapple.PopupSerializer fun(popup_menu: Grapple.PopupMenu, item: T): string

---@generic T
---@alias Grapple.PopupDeserializer fun(popup_menu: Grapple.PopupMenu, line: string): T

---@generic T
---@class Grapple.PopupTransformer<T>
---@field serialize Grapple.PopupSerializer<T>
---@field deserialize Grapple.PopupDeserializer<T>

---@alias Grapple.PopupActionFunction fun(popup_menu: Grapple.PopupMenu)

---@class Grapple.PopupAction
---@field mode string | string[]
---@field keymap string
---@field action Grapple.PopupActionFunction

---@generic T
---@class Grapple.PopupMenu<T>
---@field popup Grapple.Popup
---@field transformer Grapple.PopupTransformer<T>
---@field resolve Grapple.PopupActionFunction<R>
---@field scope Grapple.Scope
---@field items T[]

---@param window_options Grapple.WindowOptions
---@return Grapple.Popup
function popup.create_window(window_options)
    local buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buffer, "filetype", "grapple")
    vim.api.nvim_buf_set_option(buffer, "bufhidden", "wipe")

    window_options.row = math.floor(((vim.o.lines - window_options.height) / 2) - 1)
    window_options.col = math.floor((vim.o.columns - window_options.width) / 2)

    local window = vim.api.nvim_open_win(buffer, true, window_options)

    ---@type Grapple.Popup
    local popup_window = {
        buffer = buffer,
        window = window,
    }

    return popup_window
end

---@generic T
---@param serializer Grapple.PopupSerializer<T>
---@param deserializer Grapple.PopupDeserializer<T>
---@return Grapple.PopupTransformer<T>
function popup.create_transformer(serializer, deserializer)
    local transformer = {
        serialize = serializer,
        deserialize = deserializer,
    }

    return transformer
end

---@generic T
---@param popup_ Grapple.PopupWindow
---@param transformer Grapple.PopupTransformer<T>
---@param actions Grapple.PopupAction[]
---@param resolve Grapple.PopupActionFunction
---@param scope Grapple.Scope
---@param items T[]
---@return Grapple.PopupMenu<T>
function popup.open(popup_, transformer, resolve, actions, scope, items)
    local popup_menu = {
        popup = popup_,
        transformer = transformer,
        resolve = resolve,
        scope = scope,
        items = items,
    }

    vim.api.nvim_create_augroup("GrapplePopup", { clear = true })
    vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
        group = "GrapplePopup",
        buffer = popup_menu.popup.buffer,
        callback = function()
            popup.close(popup_menu)
        end,
    })

    for _, action in ipairs(actions) do
        vim.keymap.set(action.mode, action.keymap, function()
            action.action(popup_menu)
        end, { buffer = popup_menu.popup.buffer })
    end

    return popup_menu
end

---@generic T
---@param popup_menu Grapple.Popup<T>
---@param start integer
---@param end_ integer
function popup.update(popup_menu, start, end_)
    local lines = vim.tbl_map(popup_menu.transformer.serializer, popup_menu.items)
    vim.api.nvim_buf_set_lines(popup_menu.buffer, start or 0, end_ or -1, false, lines)
end

---@generic T
---@param popup_menu Grapple.PopupMenu<T>
---@return T
function popup.current_selection(popup_menu)
    local current_line = vim.api.nvim_get_current_line()
    local selection = popup_menu.transformer.deserialize(current_line)
    return selection
end

---@generic T
---@param popup_menu Grapple.PopupMenu<T>
---@return T[]
function popup.items(popup_menu)
    local lines = vim.api.nvim_buf_get_lines(popup_menu.popup.buffer, 0, -1, false)
    local parsed_items = vim.tbl_map(popup_menu.transformer.deserialize, lines)
    return parsed_items
end

---@generic T
---@param popup_menu Grapple.PopupMenu<T>
---@return any
function popup.close(popup_menu)
    local popup_resolution
    if popup_menu.resolve ~= nil then
        popup_resolution = popup_menu.resolve(popup_menu)
    end

    if vim.api.nvim_win_is_valid(popup_menu.popup.window) then
        vim.api.nvim_win_close(popup_menu.popup.window, true)
    end

    return popup_resolution
end

return popup
