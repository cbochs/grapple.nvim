local config = require("grapple.config")

local M = {}

---Initialize autocommand groups and events
function M.create_autocmds()
    vim.api.nvim_create_augroup("Grapple", { clear = true })
    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        group = "Grapple",
        callback = function()
            local tag = require("grapple.tag").find(config.scope, { buffer = 0 })
            if tag ~= nil then
                local cursor = vim.api.nvim_win_get_cursor(0)
                require("grapple.tag").update(config.scope, tag, cursor)
            end
        end,
    })

    vim.api.nvim_create_augroup("Grapple", { clear = true })
    vim.api.nvim_create_autocmd({ "VimLeave" }, {
        group = "Grapple",
        callback = function()
            require("grapple.tag").save(config.save_path)
        end,
    })
end

return M
