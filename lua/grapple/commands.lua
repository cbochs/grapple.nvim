local M = {}

local function parse_options(fargs)
    local options = {}
    for _, arg_string in pairs(fargs) do
        local delimiter_location = string.find(arg_string, "=")
        local arg_name = string.sub(arg_string, 1, delimiter_location - 1)
        local arg_value = string.sub(arg_string, delimiter_location + 1)
        options[arg_name] = tonumber(arg_value) or arg_value
    end
    return options
end

function M.create()
    vim.api.nvim_create_user_command("GrappleTag", function(opts)
        require("grapple").tag(parse_options(opts.fargs))
    end, { desc = "Tag a buffer", nargs = "*" })

    vim.api.nvim_create_user_command("GrappleUntag", function(opts)
        require("grapple").untag(parse_options(opts.fargs))
    end, { desc = "Untag a buffer", nargs = "*" })

    vim.api.nvim_create_user_command("GrappleToggle", function(opts)
        require("grapple").toggle(parse_options(opts.fargs))
    end, { desc = "Toggle a tag", nargs = "*" })

    vim.api.nvim_create_user_command("GrappleSelect", function(opts)
        require("grapple").select(parse_options(opts.fargs))
    end, { desc = "Select a tag", nargs = "*" })

    vim.api.nvim_create_user_command("GrappleReset", function(opts)
        local scope = opts.fargs[1] or nil
        require("grapple").reset(scope)
    end, { desc = "Reset scoped tags" })

    vim.api.nvim_create_user_command("GrapplePopup", function(opts)
        local menu_type = opts.fargs[1]
        if menu_type == "tags" then
            require("grapple").popup_tags()
        elseif menu_type == "scopes" then
            require("grapple").popup_scopes()
        else
            error("Incorrect popup type. Must be one of 'tags' or 'scopes'")
        end
    end, { desc = "Opens the grapple popup menu", nargs = "*" })
end

return M
