---@class grapple.lualine.component
---@field options grapple.statusline.options
local Component = require("lualine.component"):extend()

---@param opts? grapple.statusline.options
function Component:init(opts)
    Component.super:init(opts)
end

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
        local App = require("grapple.app")
        local app = App.get()

        -- stylua: ignore
        self.options = vim.tbl_deep_extend("keep",
            self.options,
            { include_icon = false },
            app.settings.statusline
        )
    end

    return grapple.statusline(self.options)
end

return Component
