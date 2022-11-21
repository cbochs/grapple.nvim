local M = {}

---Initialize autocommand groups and events
function M.create_autocmds()
    vim.api.nvim_create_augroup("Grapple", { clear = true })

    -- Save file tags when exiting
    vim.api.nvim_create_autocmd({ "VimLeave" }, {
        group = "Grapple",
        callback = function()
            require("grapple").save()
        end,
    })

    -- Update file tag cursor
    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        group = "Grapple",
        pattern = "*",
        callback = function()
            local config = require("grapple.config")
            local tag = require("grapple").find()
            if tag ~= nil then
                local cursor = vim.api.nvim_win_get_cursor(0)
                require("grapple.tags").update(config.scope, tag, cursor)
            end
        end,
    })

    -- Update the "static" scope when entering nvim
    vim.api.nvim_create_autocmd({ "VimEnter" }, {
        group = "Grapple",
        callback = function()
            local types = require("grapple.types")
            require("grapple.scope").update(types.scope.static)
        end,
    })

    -- Update the "directory" scope when the directory changes
    vim.api.nvim_create_autocmd({ "DirChanged" }, {
        group = "Grapple",
        callback = function()
            local types = require("grapple.types")
            require("grapple.scope").update(types.scope.directory)
        end,
    })

    -- Update the "lsp" scope when LSP changes
    vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
        group = "Grapple",
        callback = function()
            local types = require("grapple.types")
            require("grapple.scope").update(types.scope.lsp)
        end,
    })
end

return M
