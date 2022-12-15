local path = require("grapple.path")

---@type Grapple.Settings
local settings = {}

---@class Grapple.Settings
local DEFAULT_SETTINGS = {
    ---@type "debug" | "info" | "warn" | "error"
    log_level = "warn",

    ---Can be either the name of a builtin scope resolver,
    ---or a custom scope resolver
    ---@type string | Grapple.ScopeResolver
    scope = "git",

    ---The save location for tags
    ---@type string
    save_path = path.append(vim.fn.stdpath("data"), "grapple"),

    ---Window options used for the popup menu
    popup_options = {
        relative = "editor",
        width = 60,
        height = 12,
        style = "minimal",
        focusable = false,
        border = "single",
    },

    integrations = {
        ---Support for saving tag state using resession.nvim
        resession = false,
    },
}

---@type Grapple.Settings
local _settings = DEFAULT_SETTINGS

---@param overrides? Grapple.Settings
function settings.update(overrides)
    _settings = vim.tbl_deep_extend("force", DEFAULT_SETTINGS, overrides or {})
end

setmetatable(settings, {
    __index = function(_, index)
        return _settings[index]
    end,
})

return settings
