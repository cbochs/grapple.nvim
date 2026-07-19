local Grapple = require("grapple")

local M = {}

---@param opts? { scope?: string, id?: string }
function M.open_tags(opts)
    opts = opts or {}

    local tags, err = Grapple.tags({ scope = opts.scope, id = opts.id })
    if not tags then
        ---@diagnostic disable-next-line: param-type-mismatch
        vim.notify(err, vim.log.levels.ERROR)
        return
    end

    if #tags == 0 then
        vim.notify("No tags in current scope", vim.log.levels.INFO)
        return
    end

    local picker_opts = opts

    local items = {}
    for i, tag in ipairs(tags) do
        local cursor = tag.cursor or { 1, 0 }
        local short = vim.fn.fnamemodify(tag.path, ":~:.")
        local text = tag.name and ("[" .. tag.name .. "] " .. short) or short
        table.insert(items, {
            idx = i,
            score = i,
            text = text,
            file = tag.path,
            pos = { cursor[1], cursor[2] },
            -- private: accessed in actions
            _path = tag.path,
            _name = tag.name,
        })
    end

    require("snacks").picker.pick({
        title = "Grapple Tags",
        items = items,
        format = function(item, _)
            local short = vim.fn.fnamemodify(item._path, ":~:.")
            if item._name then
                return {
                    { "[" .. item._name .. "] ", "GrappleName" },
                    { short, "Normal" },
                }
            end
            return { { short, "Normal" } }
        end,
        preview = "file",
        confirm = function(self, item)
            self:close()
            if item then
                Grapple.select({ path = item._path, scope = picker_opts.scope, scope_id = picker_opts.id })
            end
        end,
        actions = {
            delete_tag = function(self, item)
                if item then
                    Grapple.untag({ path = item._path, scope = picker_opts.scope, scope_id = picker_opts.id })
                end
                self:close()
                vim.schedule(function()
                    M.open_tags(picker_opts)
                end)
            end,
            rename_tag = function(self, item)
                if not item then
                    return
                end
                local path = item._path
                self:close()
                local Path = require("grapple.path")
                vim.schedule(function()
                    vim.ui.input({ prompt = string.format("Rename %s: ", Path.fs_short(path)) }, function(name)
                        if name == nil then
                            return
                        end
                        Grapple.tag({
                            path = path,
                            name = name ~= "" and name or nil,
                            scope_id = picker_opts.id,
                        })
                        M.open_tags(picker_opts)
                    end)
                end)
            end,
        },
        win = {
            input = {
                keys = {
                    ["<C-x>"] = { "delete_tag", mode = { "n", "i" }, desc = "Delete tag" },
                    ["<C-r>"] = { "rename_tag", mode = { "n", "i" }, desc = "Rename tag" },
                },
            },
        },
    })
end

return M
