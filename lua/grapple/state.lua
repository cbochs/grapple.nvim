local Path = require("plenary.path")
local settings = require("grapple.settings")

local state = {}

---Reference: https://github.com/golgote/neturl/blob/master/lib/net/url.lua
---@param str string
---@return string
local function encode(str)
    return (
        str:gsub("([^%w])", function(v)
            return string.upper(string.format("%%%02x", string.byte(v)))
        end)
    )
end

-- luacheck: ignore
---@param str string
---@return string
local function decode(str)
    return (str:gsub("%%(%x%x)", function(c)
        return string.char(tonumber(c, 16))
    end))
end

---Serialize a lua table as json idempotently.
---@param state_ table | string
---@return string
local function serialize(state_)
    if type(state_) == "string" then
        return state_
    end
    return vim.json.encode(state_)
end

---Deserialize a json blob into a lua table idempotently.
---@param serialized_state table | string
---@return table
local function deserialize(serialized_state)
    if type(serialized_state) ~= "string" then
        return serialized_state
    end
    return vim.json.decode(serialized_state)
end

---@param state_ table
---@param save_path? string
function state.prune(state_, save_path)
    save_path = Path:new(save_path or settings.save_path)
    for state_key, sub_state in pairs(state_) do
        local state_path = save_path / encode(state_key)
        if vim.tbl_isempty(sub_state) and state_path:exists() then
            state_path:rm()
        end
    end
end

---@param state_ table
---@param save_path? string
function state.save(state_, save_path)
    save_path = Path:new(save_path or settings.save_path)
    if not save_path:exists() then
        save_path:mkdir()
    end

    for state_key, sub_state in pairs(state_) do
        -- todo(cbochs): sync state properly instead of just overwriting it
        local state_path = save_path / encode(state_key)
        if not vim.tbl_isempty(sub_state) and state_key ~= "none" then
            local serialized_state = serialize(sub_state)
            state_path:write(serialized_state, "w")
        end
    end
end

---@param state_key
---@param save_path? string
---@return table
function state.load(state_key, save_path)
    save_path = Path:new(save_path or settings.save_path)

    local state_path = save_path / encode(state_key)
    if not state_path:exists() then
        return
    end

    local serialized_state = state_path:read()
    local loaded_state = deserialize(serialized_state)

    return loaded_state
end

---@param save_path string
---@param old_save_path string
---@param new_save_path string
function state.migrate(save_path, old_save_path, new_save_path)
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
    local loaded_state = deserialize(serialized_state)
    state.save(loaded_state, tostring(new_save_path))

    Path:new(old_save_path):rm()
end

return state
