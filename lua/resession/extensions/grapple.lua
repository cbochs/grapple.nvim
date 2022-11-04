local M = {}

---Get the saved data for this extension
---@return any
M.on_save = function()
    print("Saving tags")
    return require("grapple.tags")._raw_save()
end

---Restore the extension state
---@param data table The value returned from on_save
M.on_load = function(data)
    print("Loading tags")
    require("grapple.tags")._raw_load(data)
end

return M
