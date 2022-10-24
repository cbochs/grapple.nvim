local config = require("grapple.config")
local marks = require("grapple.marks")

local M = {}

local function file_patterns()
    local marked_files = marks.marked_files(config.project_root)
    if #marked_files == 0 then
        return "notarealfile"
    else
        return marked_files
    end
end

---Initialize autocommand groups and events
function M.create_autocmds()
    vim.api.nvim_create_augroup("GrappleUpdate", { clear = true })
    M.update_autocmds()

    vim.api.nvim_create_augroup("GrappleSave", { clear = true })
    vim.api.nvim_create_autocmd(
        { "VimLeave" },
        {
            group = "GrappleSave",
            callback = function()
                marks.save(config.state_path)
            end
        }
    )
end

---Update autocommand correct file patterns
function M.update_autocmds()
    vim.api.nvim_clear_autocmds({ group = "GrappleUpdate" })
    vim.api.nvim_create_autocmd(
        { "BufLeave" },
        {
            group = "GrappleUpdate",
            pattern = file_patterns(),
            callback = function()
                marks.update_mark(
                    config.project_root,
                    vim.api.nvim_win_get_cursor(0),
                    { buffer = 0 }
                )
            end,
        }
    )
end

return M
