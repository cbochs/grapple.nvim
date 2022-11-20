local M = {}

M.groups = {
    lualine_tag_active = "LualineGrappleTagActive",
    lualine_tag_inactive = "LualineGrappleTagInactive",
}

M.default = {
    [M.groups.lualine_tag_active] = { fg = "#a6e3a1" },
    [M.groups.lualine_tag_inactive] = { fg = "#313244" },
}

function M.load()
    for _, group in pairs(M.groups) do
        vim.api.nvim_set_hl(0, group, M.default[group] or {})
    end
end

return M
