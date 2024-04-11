---@class grapple.lualine.component
---@field options grapple.statusline.options
local Component = require("lualine.component"):extend()

---@param opts? grapple.statusline.options
function Component:init(opts)
    Component.super:init(opts)
end

-- TODO: Keep for reference, remove later
-- ---@return string | nil
-- function Component:update_status()
--     if package.loaded["grapple"] == nil then
--         return
--     end
--
--     local ok, grapple = pcall(require, "grapple")
--     if not ok then
--         return
--     end
--
--     -- Lazyily add statusline options to the component
--     if not self.options.icon or not self.options.active or not self.options.inactive then
--         local App = require("grapple.app")
--         local app = App.get()
--
--         -- stylua: ignore
--         self.options = vim.tbl_deep_extend("keep",
--             self.options,
--             { include_icon = false },
--             app.settings.statusline
--         )
--     end
--
--     return grapple.statusline(self.options)
-- end

---@return string | nil
function Component:update_status()
    if package.loaded["grapple"] == nil then
        return
    end

    local ok, grapple = pcall(require, "grapple")
    if not ok then
        return
    end

    -- Lazyily add statusline options to the component
    if not self.options.icon or not self.options.active or not self.options.inactive then
        local app = require("grapple.app").get()
        app.settings.statusline["include_icon"] = false -- lualine handles the icon

        -- No icon for the short formatter:
        if app.settings.statusline.builtin_formatter == "short" then
            self.options["icons_enabled"] = false
        end

        self.options = vim.tbl_deep_extend(
            "keep", -- options for lualine
            self.options,
            app.settings.statusline
        )
    end
    return grapple.statusline()
end

return Component
