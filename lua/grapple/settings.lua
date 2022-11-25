local Path = require("plenary.path")
local types = require("grapple.types")

---@class Grapple.Settings
local DEFAULT_SETTINGS = {
    ---@type "debug" | "info" | "warn" | "error"
    log_level = "warn",

    ---The scope used when creating, selecting, and deleting tags
    ---@type Grapple.ScopeKey | Grapple.ScopeResolver
    scope = types.scope.global,

    ---The save location for tags
    ---@type string
    save_path = tostring(Path:new(vim.fn.stdpath("data")) / "grapple"),

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
local settings = vim.deepcopy(DEFAULT_SETTINGS)

---@param overrides? Grapple.Settings
function settings.update(overrides)
    settings = vim.tbl_deep_extend("force", DEFAULT_SETTINGS, overrides or {})
end

return settings
