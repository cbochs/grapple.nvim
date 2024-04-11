-- TODO: Test include_icon
-- TODO: Test tag with name
-- TODO: Test tag and quicklit
-- TODO: Test is_buffer_tagged method

---@diagnostic disable-next-line: undefined-field
local same = assert.same
local icon = "󰛢"

local function unload()
    package.loaded["grapple"] = nil
    package.loaded["grapple.statusline"] = nil
    require("grapple").reset()
end
local function add(buffer_names, grapple)
    for _, name in ipairs(buffer_names) do
        vim.cmd("edit " .. name)
        grapple.toggle()
    end
end
describe("Statusline .format default", function()
    before_each(unload)
    it("is correct without tags", function()
        same("", require("grapple").statusline())
    end)
    it("is correct having 2 tags, current buffer is last", function()
        local Grapple = require("grapple")
        add({ "foo", "bar" }, Grapple)
        same(icon .. "  1 [2]", Grapple.statusline())
    end)
    it("is correct having 5 tags, current buffer is 2", function()
        local Grapple = require("grapple")
        add({ "foo", "bar", "baz", "xyz", "zyx" }, Grapple)
        vim.cmd("edit " .. "bar")
        same(icon .. "  1 [2] 3  4  5 ", Grapple.statusline())
    end)
    it("is correct having 5 tags, current buffer is not tagged", function()
        local Grapple = require("grapple")
        add({ "foo", "bar", "baz", "xyz", "zyx" }, Grapple)
        vim.cmd("edit " .. "abc")
        same(icon .. "  1  2  3  4  5 ", Grapple.statusline())
    end)
end)

describe("Statusline .format short", function()
    before_each(function()
        unload()
        require("grapple").setup({ statusline = { builtin_formatter = "short" } })
    end)
    it("is correct without tags", function()
        same("", require("grapple").statusline())
    end)
    it("is correct having 2 tags, current buffer is last", function()
        local Grapple = require("grapple")
        add({ "foo", "bar" }, Grapple)
        same("2", Grapple.statusline())
    end)
    it("is correct having 5 tags, current buffer is 2", function()
        local Grapple = require("grapple")
        add({ "foo", "bar", "baz", "xyz", "zyx" }, Grapple)
        vim.cmd("edit " .. "bar")
        same("2", Grapple.statusline())
    end)
    it("is correct having 5 tags, current buffer is not tagged", function()
        local Grapple = require("grapple")
        add({ "foo", "bar", "baz", "xyz", "zyx" }, Grapple)
        vim.cmd("edit " .. "abc")
        same("", Grapple.statusline())
    end)
end)

---@type grapple.formatter
local function custom(opts_in, data)
    local opts = { -- condensed line showing 4 slots and an optional extra slot
        max_slots = 4,
        inactive = "%s",
        active = "[%s]",
        empty_slot = "·", -- #slots > #tags, middledot
        more_marks_indicator = "…", -- #slots < #tags, horizontal elipsis
        more_marks_active_indicator = "[…]",
    }
    if data.scope_name == "git" then
        data.scope_name = ""
    end
    local prefix = string.format("%s%s%s", opts_in.icon, data.scope_name == "" and "" or " ", data.scope_name)

    -- build slots:
    local status = {}
    local max_tags = #data.tags
    for i = 1, opts.max_slots do
        local tag_fmt = opts.inactive
        local tag_str = "" .. i
        if i > max_tags then -- more slots then ...
            tag_str = opts.empty_slot
        else
            local tag = data.tags[i]
            if data.current and data.current.path == tag.path then
                tag_fmt = opts.active
            end
        end
        table.insert(status, string.format(tag_fmt, tag_str))
    end
    -- extra slot:
    if max_tags > opts.max_slots then -- more marks then...
        local ind = opts.more_marks_indicator
        for i = opts.max_slots + 1, max_tags do
            local tag = data.tags[i]
            if data.current and data.current.path == tag.path then
                ind = opts.more_marks_active_indicator
                break
            end
        end
        table.insert(status, ind)
    end

    return prefix .. " " .. table.concat(status)
end

describe("Statusline .format custom formatter", function()
    before_each(function()
        unload()
        require("grapple").setup({
            statusline = {
                formatter = custom,
            },
        })
    end)
    it("is correct without tags", function()
        same(icon .. " ····", require("grapple").statusline())
    end)
    it("is correct having 2 tags, current buffer is last", function()
        local Grapple = require("grapple")
        add({ "foo", "bar" }, Grapple)
        same(icon .. " 1[2]··", Grapple.statusline())
    end)
    it("is correct having 5 tags, current buffer is 2", function()
        local Grapple = require("grapple")
        add({ "foo", "bar", "baz", "xyz", "zyx" }, Grapple)
        vim.cmd("edit " .. "bar")
        same(icon .. " 1[2]34…", Grapple.statusline())
    end)
    it("is correct having 5 tags, current buffer is last", function()
        local Grapple = require("grapple")
        add({ "foo", "bar", "baz", "xyz", "zyx" }, Grapple)
        same(icon .. " 1234[…]", Grapple.statusline())
    end)
    it("is correct having 5 tags, current buffer is not tagged", function()
        local Grapple = require("grapple")
        add({ "foo", "bar", "baz", "xyz", "zyx" }, Grapple)
        vim.cmd("edit " .. "abc")
        same(icon .. " 1234…", Grapple.statusline())
    end)
end)
