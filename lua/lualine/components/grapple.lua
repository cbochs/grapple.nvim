---@class grapple.lualine.component
---@field options grapple.lualine.options
local Component = require("lualine.component"):extend()

---@class grapple.lualine.options
local defaults = {
    icon = "󰛢",
    inactive = " %s ",
    active = "[%s]",
}

---@class grapple.lualine.options
function Component:init(opts)
    opts = vim.tbl_deep_extend("keep", opts or {}, defaults)
    Component.super:init(opts)
end

---@param opts? grapple.options
function Component:update_status(opts)
    if package.loaded["grapple"] == nil then
        return
    end

    local ok, grapple = pcall(require, "grapple")
    if not ok then
        return
    end

    opts = opts or {}
    local merged = vim.tbl_deep_extend("force", opts, { buffer = 0 })
    local tags, err = grapple.tags(merged)
    if not tags then
        return err
    end

    local current = grapple.find(merged)

    local App = require("grapple.app")
    local app = App.get()
    local quick_select = app.settings:quick_select()
    local output = {}
    for i, tag in ipairs(tags) do
        -- stylua: ignore
        local tag_str = tag.name and tag.name
            or quick_select[i] and quick_select[i]
            or i

        local tag_fmt = self.options.inactive
        if current and current.path == tag.path then
            tag_fmt = self.options.active
        end
        table.insert(output, string.format(tag_fmt, tag_str))
    end

    return table.concat(output)
end

return Component

--[[
local lualine_require = require("lualine_require")
local M = lualine_require.require("lualine.component"):extend()

local hl = require("harpoon-lualine")

local default_options = {
    icon = "󰀱 ",
    indicators = { "1", "2", "3", "4" },
    active_indicators = { "[1]", "[2]", "[3]", "[4]" },
}

function M:init(options)
    M.super.init(self, options)
    self.options = vim.tbl_deep_extend("keep", self.options or {}, default_options)
end

function M:update_status()
    local harpoon_loaded = package.loaded["harpoon"] ~= nil
    if not harpoon_loaded then
        return "Harpoon not loaded"
    end

    return hl.status(self.options)
end

return M--]]
