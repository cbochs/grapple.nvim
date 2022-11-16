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
    local file = io.open(save_path, "w")
    if file ~= nil then
        file:write(serialized_state)
        file:close()
    end
end

---Load a lua table from a given file.
---@param save_path string
---@return table
function M.load(save_path)
    local file = io.open(save_path, "r")
    if file ~= nil then
        local serialized_state = file:read("*all")
        local state = M.deserialize(serialized_state)
        return state
    end
    return {}
end

---Check whether a file exists.
---@param file_path string
---@return boolean
function M.file_exists(file_path)
    local save_dir = vim.fs.dirname(file_path)
    local save_name = vim.fs.basename(file_path)
    local found_files = vim.fs.find(save_name, { path = save_dir })
    return #found_files > 0
end

---Attempt to convert a file path into its absolute counterpart.
---@param file_path string
---@return string | nil
function M.resolve_file_path(file_path)
    local absolute_path = vim.fn.expand(file_path)
    if string.sub(absolute_path, 1, 1) ~= "/" then
        absolute_path = vim.fn.getcwd() .. "/" .. absolute_path
    end
    if not M.file_exists(absolute_path) then
        return
    end
    return absolute_path
end

return M
