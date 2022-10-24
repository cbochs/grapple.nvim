local jump = require("grapple.jump")
local marks = require("grapple.marks")

local M = {}

function M.create_commands()
    vim.api.nvim_create_user_command(
        "GrappleMark",
        function(opts) marks.mark(opts.args) end,
        { desc = "Mark a buffer" }
    )

    vim.api.nvim_create_user_command(
        "GrappleUnmark",
        function(opts) marks.unmark(opts.args) end,
        { desc = "Unmark a buffer" }
    )

    vim.api.nvim_create_user_command(
        "GrappleToggle",
        function(opts) marks.toggle(opts.args) end,
        { desc = "Toggle a mark" }
    )

    vim.api.nvim_create_user_command(
        "GrappleSelect",
        function(opts) marks.select(opts.args) end,
        { desc = "Select a mark" }
    )

    vim.api.nvim_create_user_command(
        "GrappleJumpForward",
        function(_) jump.jump_forward() end,
        { desc = "Jump to the next marked buffer" }
    )

    vim.api.nvim_create_user_command(
        "GrappleJumpBackward",
        function(_) jump.jump_backward() end,
        { desc = "Jump to the previous marked buffer" }
    )
end

return M
