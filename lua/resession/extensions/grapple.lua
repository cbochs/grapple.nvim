local M = {}

---@return table<string, Grapple.Tag[]>
M.on_save = function()
    return require("grapple.tags")._raw_save()
end

---@param data table<string, Grapple.Tag[]>
M.on_load = function(data)
    require("grapple.tags")._raw_load(data)
end

return M
