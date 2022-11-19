local Path = require("plenary.path")

local M = {}

---Serialize a lua table as json idempotently.
---@param state table | string
---@return string
function M.serialize(state)
    if type(state) == "string" then
        return state
    end
    return vim.fn.json_encode(state)
end

---Deserialize a json blob into a lua table idempotently.
---@param serialized_state table | string
---@return table
function M.deserialize(serialized_state)
    if type(serialized_state) ~= "string" then
        return serialized_state
    end
    return vim.fn.json_decode(serialized_state)
end

---Save a lua table to a given file.
---@param save_path string
---@param state table
---@return nil
function M.save(save_path, state)
    local serialized_state = M.serialize(state)
    Path:new(save_path):write(serialized_state, "w")
end

---Load a lua table from a given file.
---@param save_path string
---@return table
function M.load(save_path)
    local serialized_state = Path:new(save_path):read()
    local state = M.deserialize(serialized_state)
    return state
end

---Check whether a file exists.
---@param path string
---@return boolean
function M.path_exists(path)
    return Path:new(path):exists()
end

---Attempt to convert a file path into its absolute counterpart.
---@param path string
---@return string | nil
function M.resolve_path(path)
    local expanded_path = Path:new(path):expand()
    if not M.path_exists(path) then
        return nil
    end
    return expanded_path
end

return M
