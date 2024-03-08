local Util = {}

---Escapes a string so it can be used as a string pattern
---@param str string
---@return string escaped string
function Util.escape(str)
    local escaped = string.gsub(str, "%p", "%%%1")
    return escaped
end

---Sorts list elements in a given order, *not-in-place*, from `list[1]` to `list[#list]`.
---@generic T
---@param list T[]
---@param fn fun(a: T, b: T): boolean
---@return T[]
function Util.sort(list, fn)
    list = vim.deepcopy(list)
    table.sort(list, fn)
    return list
end

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

---@generic T
---@param tbl T[]
---@param removed T[]
---@return T[]
function Util.subtract(tbl, removed)
    local lookup = {}
    for _, value in ipairs(removed) do
        lookup[value] = true
    end

    local subtracted = vim.deepcopy(tbl)
    for i = #subtracted, 0, -1 do
        if lookup[subtracted[i]] then
            table.remove(subtracted, i)
        end
    end

    return subtracted
end

---@generic T
---@param value T
---@param n integer
---@return T[]
function Util.ntimes(value, n)
    local result = {}
    for _ = 1, n do
        table.insert(result, value)
    end
    return result
end

---@generic T
---@param list_a T[]
---@param list_b T[]
---@return boolean
function Util.same(list_a, list_b)
    if #list_a ~= #list_b then
        return false
    end

    return #Util.subtract(list_a, list_b) == 0
end

---Transformer adds a prefix to a string value
---@param prefix string
---@return fun(value: string): string
function Util.with_prefix(prefix)
    return function(value)
        return prefix .. value
    end
end

---Transformer adds a suffix to a string value
---@param suffix string
---@return fun(value: string): string
function Util.with_suffix(suffix)
    return function(value)
        return value .. suffix
    end
end

---Transformer to pick the key out of a "key=value" string
---@param value string
---@return string | nil
function Util.match_key(value)
    local key, _ = string.match(value, "^(.*)=(.*)$")
    return key
end

---Predicate to return if a value is starts with a prefix
---@param prefix string
---@return fun(value: string): boolean
function Util.startswith(prefix)
    return function(value)
        return vim.startswith(value, prefix)
    end
end

---Predicate to return if a string value is not empty
---@param value string
---@return boolean
function Util.not_empty(value)
    return vim.trim(value) ~= ""
end

---Predicate to return if a value is not nil
---@param value any
---@return boolean
function Util.not_nil(value)
    return value ~= nil
end

---@param str_a string
---@param str_b string
function Util.as_lower(str_a, str_b)
    return string.lower(str_a) < string.lower(str_b)
end

return Util
