local M = {}

---Initialize autocommand groups and events
function M.create()
    vim.api.nvim_create_augroup("Grapple", { clear = true })

    -- Update file tag cursor
    vim.api.nvim_create_autocmd({ "BufWinLeave", "ExitPre" }, {
        group = "Grapple",
        pattern = "*",
        callback = function(opts)
            local ok, _ = pcall(function()
                local settings = require("grapple.settings")
                local tag = require("grapple").find({ buffer = opts.buf })
                if tag ~= nil then
                    local cursor = vim.api.nvim_win_get_cursor(0)
                    local scope = require("grapple.state").ensure_loaded(settings.scope)

                    if cursor[1] ~= tag.cursor[1] or cursor[2] ~= tag.cursor[2] then
                        require("grapple.tags").update(scope, tag, cursor)
                        require("grapple").save()
                    end
                end
            end)
            if not ok then
                require("grapple.log").warn("Failed to lookup tag for current buffer on BufLeave")
            end
        end,
    })
end

return M
