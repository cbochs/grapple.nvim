local Util = {}

---@param list table
---@param fn fun(acc: any, value: any, index?: integer): any
---@param init any
---@return any
function Util.reduce(list, fn, init)
    local acc = init
    for i, v in ipairs(list) do
        if i == 1 and not init then
            acc = init
        else
            fn(acc, v, i)
        end
    end
    return acc
end

function Util.is_empty(value)
    return value ~= ""
end

function Util.is_nil(value)
    return value ~= nil
end

function Util.trim(value)
    return vim.trim(value)
end

return Util
