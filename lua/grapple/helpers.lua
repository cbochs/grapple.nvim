local helpers = {}

helpers.table = {}

---@param table_ table
---@return table
function helpers.table.to_list(table_)
    local list = {}
    for key, value in pairs(table_) do
        table.insert(list, { key, value })
    end
    return list
end

---@param table_ table
---@return table
function helpers.table.map(func, table_)
    return vim.tbl_map(function(pair)
        return func(unpack(pair))
    end, helpers.table.to_list(table_))
end

return helpers
