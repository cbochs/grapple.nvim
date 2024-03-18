local WindowActions = {}

---@class grapple.action.window_options
---
---Provided by Window
---@field window grapple.window

---@param opts grapple.action.window_options
function WindowActions.help(opts)
    local HelpContent = require("grapple.help_content")
    local Window = require("grapple.window")
    local window = Window:new(opts.window.win_opts)

    local content = HelpContent:new(opts.window.buf_id)
    window:attach(content)
    window:open()
    window:render()

    local function close_help()
        vim.cmd.close()
        opts.window:open()
        opts.window:render()
    end

    window:map("n", "?", close_help)
    window:map("n", "q", close_help)
    window:map("n", "<c-c>", close_help)
    window:map("n", "<esc>", close_help)

    opts.window:close()
end

return WindowActions
