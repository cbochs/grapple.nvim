local Grapple = require("grapple")

local M = {}

---Build a reverse-lookup table from entry string to tag.
---Entries are formatted as "path:lnum:col" for the builtin previewer.
---@param tags grapple.tag[]
---@return string[], table<string, grapple.tag>
local function build_entries(tags)
    local entries = {}
    local lookup = {} -- entry string -> tag
    for _, tag in ipairs(tags) do
        local cursor = tag.cursor or { 1, 0 }
        local entry = string.format("%s:%d:%d", tag.path, cursor[1], cursor[2] + 1)
        table.insert(entries, entry)
        lookup[entry] = tag
        -- also index by plain path as a fallback
        lookup[tag.path] = tag
    end
    return entries, lookup
end

---Resolve selected fzf entry back to a tag using the lookup table.
---@param line string
---@param lookup table<string, grapple.tag>
---@return grapple.tag | nil
local function get_tag(line, lookup)
    if lookup[line] then
        return lookup[line]
    end
    -- strip trailing :lnum:col
    local path = line:match("^(.+):%d+:%d+$") or line:match("^(.+):%d+$") or line
    return lookup[path]
end

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
    local entries, lookup = build_entries(tags)

    require("fzf-lua").fzf_exec(entries, {
        prompt = "Grapple> ",
        previewer = "builtin",
        fzf_opts = { ["--multi"] = true },
        actions = {
            ["default"] = function(selected)
                if not selected or #selected == 0 then
                    return
                end
                local tag = get_tag(selected[1], lookup)
                if tag then
                    Grapple.select({ path = tag.path, scope = picker_opts.scope, scope_id = picker_opts.id })
                end
            end,
            ["ctrl-x"] = function(selected)
                if not selected or #selected == 0 then
                    return
                end
                for _, line in ipairs(selected) do
                    local tag = get_tag(line, lookup)
                    if tag then
                        Grapple.untag({ path = tag.path, scope = picker_opts.scope, scope_id = picker_opts.id })
                    end
                end
                vim.schedule(function()
                    M.open_tags(picker_opts)
                end)
            end,
            ["ctrl-r"] = function(selected)
                if not selected or #selected == 0 then
                    return
                end
                local tag = get_tag(selected[1], lookup)
                if not tag then
                    return
                end
                local path = tag.path
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
    })
end

return M
