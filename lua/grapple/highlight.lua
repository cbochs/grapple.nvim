local M = {}

M.groups = {
    lualine_tag_active = "LualineGrappleTagActive",
    lualine_tag_inactive = "LualineGrappleTagInactive",
}

function M.load()
    --- The default theme is based off of catppuccin
    local default_theme = {
        LualineGrappleTagActive = { fg = "#a6e3a1" },
        LualineGrappleTagInactive = { fg = "#313244" },
    }

    for _, group in pairs(M.groups) do
        vim.api.nvim_set_hl(0, group, default_theme[group] or {})
    end
end

return M
