local quickfix = {}

---@class Grapple.QuickfixItem

---@generic T
---@alias Grapple.Quickfixer<T> fun(item: T): Grapple.QuickfixItem

---@generic T
---@param items T[]
---@param quickfixer Grapple.Quickfixer<T>
function quickfix.from(items, quickfixer)
    return vim.tbl_map(quickfixer, items)
end

function quickfix.set(quickfix_items)
    vim.fn.setqflist(quickfix_items, "r")
end

function quickfix.title(quickfix_title)
    vim.fn.setqflist({}, "a", { title = quickfix_title })
end

function quickfix.open()
    vim.api.nvim_cmd({ cmd = "copen" }, {})
end

function quickfix.send(title, items, quickfixer)
    local quickfix_items = quickfix.from(items, quickfixer)
    quickfix.set(quickfix_items)
    quickfix.title(title)
    quickfix.open()
end

return quickfix
