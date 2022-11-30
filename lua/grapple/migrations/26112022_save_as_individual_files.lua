local Path = require("plenary.path")
local state = require("grapple.state")

local migration = {}

---@param save_path string
---@param old_save_path string
---@param new_save_path string
function migration.migrate(save_path, old_save_path, new_save_path)
    if not Path:new(old_save_path):exists() then
        return
    end

    local log = require("grapple.log")
    local logger = log.new({ log_level = "warn", use_console = true }, false)

    if save_path ~= tostring(new_save_path) then
        logger.warn(
            "Migrating tags to their new home. "
                .. "The save path in your grapple config is no longer valid. "
                .. "For more information, "
                .. "please see https://github.com/cbochs/grapple.nvim/issues/39"
        )
    else
        logger.warn(
            "Migrating tags to their new home. "
                .. "For more information, "
                .. "please see https://github.com/cbochs/grapple.nvim/issues/39"
        )
    end

    local serialized_state = Path:new(old_save_path):read()
    local loaded_state = vim.json.decode(serialized_state)

    state.load_all(loaded_state, { persist = true })
    state.save(tostring(new_save_path))
    state.reset()

    Path:new(old_save_path):rm()
end

return migration
