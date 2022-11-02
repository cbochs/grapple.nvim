local config = require("grapple.config")
local types = require("grapple.types")

local M = {}

---Initialize autocommand groups and events
function M.create_autocmds()
    vim.api.nvim_create_augroup("Grapple", { clear = true })
    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        group = "Grapple",
        pattern = "*",
        callback = function()
            local tag = require("grapple.tags").find(config.scope, { buffer = 0 })
            if tag ~= nil then
                local cursor = vim.api.nvim_win_get_cursor(0)
                require("grapple.tags").update(config.scope, tag, cursor)
            end
        end,
    })

    vim.api.nvim_create_autocmd({ "VimLeave" }, {
        group = "Grapple",
        callback = function()
            if config.scope ~= types.Scope.NONE then
                require("grapple.tags").save(config.save_path)
            end
        end,
    })
end

return M
