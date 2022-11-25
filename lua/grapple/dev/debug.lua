vim.api.nvim_create_user_command("DebugGrapple", function()
    -- Unload all packages
    for name, _ in pairs(package.loaded) do
        if name:match("^grapple") then
            package.loaded[name] = nil
        end
    end
    vim.api.nvim_clear_autocmds({ group = "Grapple" })
end, {})
