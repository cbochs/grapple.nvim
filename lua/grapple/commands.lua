local jump = require("grapple.jump")
local marks = require("grapple.marks")

local M = {}

local function parse_mark_options(fargs)
    local mark_options = {}
    for _, arg_string in pairs(fargs) do
        local delimiter_location = string.find(arg_string, "=")
        local arg_name = string.sub(arg_string, 1, delimiter_location - 1)
        local arg_value = string.sub(arg_string, delimiter_location + 1)
        mark_options[arg_name] = tonumber(arg_value) or arg_value
    end
    return mark_options
end

function M.create_commands()
    vim.api.nvim_create_user_command(
        "GrappleMark",
        function(opts) marks.mark(parse_mark_options(opts.fargs)) end,
        { desc = "Mark a buffer", nargs = "*" }
    )

    vim.api.nvim_create_user_command(
        "GrappleUnmark",
        function(opts) marks.unmark(parse_mark_options(opts.fargs)) end,
        { desc = "Unmark a buffer", nargs = "*" }
    )

    vim.api.nvim_create_user_command(
        "GrappleToggle",
        function(opts) marks.toggle(parse_mark_options(opts.fargs)) end,
        { desc = "Toggle a mark", nargs = "*" }
    )

    vim.api.nvim_create_user_command(
        "GrappleSelect",
        function(opts) marks.select(parse_mark_options(opts.fargs)) end,
        { desc = "Select a mark", nargs = "*" }
    )

    vim.api.nvim_create_user_command(
        "GrappleReset",
        function(_) marks.reset() end,
        { desc = "Reset marks for the current project" }
    )

    vim.api.nvim_create_user_command(
        "GrappleResetAll",
        function(_) marks.reset_marks() end,
        { desc = "Reset marks for the current project" }
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
