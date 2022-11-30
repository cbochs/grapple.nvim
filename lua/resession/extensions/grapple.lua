local M = {}

---@return table<string, Grapple.Tag[]>
M.on_save = function()
    return require("grapple.state").state()
end

---@param data table<string, Grapple.Tag[]>
M.on_load = function(data)
    require("grapple.state").load_all(data)
end

return M
