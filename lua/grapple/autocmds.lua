local M = {}

---Initialize autocommand groups and events
function M.create_autocmds()
    vim.api.nvim_create_augroup("Grapple", { clear = true })

    -- Save file tags when exiting
    vim.api.nvim_create_autocmd({ "VimLeave" }, {
        group = "Grapple",
        callback = function()
            local ok, _ = pcall(require("grapple").save)
            if not ok then
                require("grapple.log").warn("Unable to save tags when exiting neovim")
            end
        end,
    })

    -- Update file tag cursor
    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        group = "Grapple",
        pattern = "*",
        callback = function()
            local settings = require("grapple.settings")
            local ok, tag = pcall(require("grapple").find)
            if not ok then
                require("grapple.log").warn("Failed to lookup tag for current buffer on BufLeave")
                return
            end
            if tag ~= nil then
                local cursor = vim.api.nvim_win_get_cursor(0)
                require("grapple.tags").update(settings.scope, tag, cursor)
            end
        end,
    })
end

return M
