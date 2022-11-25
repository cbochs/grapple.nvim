local Path = require("plenary.path")
local settings = require("grapple.settings")

local M = {}

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

---@param str string
---@return string
local function decode(str)
    return (str:gsub("%%(%x%x)", function(c)
        return string.char(tonumber(c, 16))
    end))
end

---Serialize a lua table as json idempotently.
---@param state table | string
---@return string
local function serialize(state)
    if type(state) == "string" then
        return state
    end
    return vim.fn.json_encode(state)
end

---Deserialize a json blob into a lua table idempotently.
---@param serialized_state table | string
---@return table
local function deserialize(serialized_state)
    if type(serialized_state) ~= "string" then
        return serialized_state
    end
    return vim.fn.json_decode(serialized_state)
end

---@param state_key
---@param save_path? string
---@return table
function M.load(state_key, save_path)
    save_path = Path:new(save_path or settings.save_path)

    local state_path = save_path / encode(state_key)
    if not state_path:exists() then
        return
    end

    local serialized_state = Path:new(state_path):read()
    local state = deserialize(serialized_state)

    return state
end

---@param state table
---@param save_path? string
---@return nil
function M.save(state, save_path)
    save_path = Path:new(save_path or settings.save_path)
    if not save_path:exists() then
        save_path:mkdir()
    end

    for state_key, sub_state in pairs(state) do
        -- todo(cbochs): sync state properly instead of just overwriting it
        local state_path = save_path / encode(state_key)
        if vim.tbl_isempty(sub_state) and state_path:exists() then
            state_path:rm()
        else
            local serialized_state = serialize(sub_state)
            state_path:write(serialized_state, "w")
        end
    end
end

---@param save_path? string
function M.available(save_path)
    save_path = Path:new(save_path or settings.save_path)
    if not save_path:exists() then
        return 0
    end

    local available = {}
    for encoded_key, _ in vim.fs.dir(tostring(save_path)) do
        table.insert(available, decode(encoded_key))
    end

    return available
end

return M
