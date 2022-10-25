local log = require("grapple.log")

---@class GrappleConfig
---@field log_level "error" | "warn" | "info" | "debug"
---@field project_root string
---@field state_path string
local M = {}

local _config = nil

---The default configuration for grapple.nvim
---@return GrappleConfig
function M.default()
    ---@type GrappleConfig
    local _default = {
        log_level = "warn",
        project_root = vim.fn.getcwd(),
        state_path = vim.fn.stdpath("data") .. "/" .. "grapple.json",
    }
    return _default
end

---Attempt to find a configuration option from a dot-delimited key.
---@param key_string string
---@return string
function M.get(key_string)
    local current_value = _config
    for key in string.gmatch(key_string, "[^.]+") do
        if current_value[key] == nil then
            log.error("ConfigError - Invalid option. key_string: " .. key_string)
            error("ConfigError - Invalid option. key_string: " .. key_string)
        end
        current_value = current_value[key]
    end
    return current_value
end

---Initialize configuration.
---@param opts? GrappleConfig
---@param force? boolean
function M.load(opts, force)
    opts = opts or {}
    force = force or false

    if _config ~= nil and not force then
        log.warn("Config has already been loaded.")
        return nil
    end

    local merged_config = vim.tbl_deep_extend("force", M.default(), opts)

    local errors = M.validate(merged_config)
    if #errors > 0 then
        log.error("ValidationError - Invalid options: " .. vim.inspect(errors))
        error("ValidationError - Invalid options: " .. vim.inspect(errors))
        return nil
    end

    _config = merged_config
end

function M.validate(config, expected_config)
    config = config or _config
    expected_config = expected_config or M.default()

    local errors = {}
    for key, _ in pairs(config) do
        if expected_config[key] == nil then
            table.insert(key)
        end
        if type(config[key]) == "table" then
            local nested_errors = M.validate(config[key], expected_config[key])
            for i, error_key in pairs(nested_errors) do
                nested_errors[i] = key .. "." .. error_key
            end
            errors = { unpack(errors), unpack(nested_errors) }
        end
    end

    return errors
end

setmetatable(M, {
    __index = function(_, index)
        local value = _config[index]
        if value == nil then
            log.error("ConfigError - Invalid option. index: " .. index)
            error("ConfigError - Invalid option. index: " .. index)
        end
        return value
    end,

    __newindex = function(_, _)
        log.error("ConfigError - Config is read-only")
        error("ConfigError - Config is read-only")
    end,
})

return M
