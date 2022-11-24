local Path = require("plenary.path")
local types = require("grapple.types")

---@type Grapple.Config
local M = {}

---@class Grapple.Config
local DEFAULT_CONFIG = {
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

---@type Grapple.Config
local _config = DEFAULT_CONFIG

---@param opts? Grapple.Config
function M.load(opts)
    opts = opts or {}

    ---@type Grapple.Config
    _config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, opts)
end

setmetatable(M, {
    __index = function(_, index)
        return _config[index]
    end,
})

return M
