---@diagnostic disable-next-line: undefined-field
local same = assert.same
local icon = "󰛢"

local function unload()
    package.loaded["grapple"] = nil
    package.loaded["grapple.app"] = nil
    package.loaded["grapple.statusline"] = nil
    package.loaded["grapple.settings"] = nil
    require("grapple").reset()
end
local function add(buffer_names, grapple)
    for _, name in ipairs(buffer_names) do
        vim.cmd.edit(name)
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
        vim.cmd.edit("bar")
        same(icon .. "  1 [2] 3  4  5 ", Grapple.statusline())
    end)
    it("is correct having 5 tags, current buffer is not tagged", function()
        local Grapple = require("grapple")
        add({ "foo", "bar", "baz", "xyz", "zyx" }, Grapple)
        vim.cmd.edit("abc")
        same(icon .. "  1  2  3  4  5 ", Grapple.statusline())
    end)
    it("is correct when a tag is untagged", function()
        local Grapple = require("grapple")
        add({ "foo", "bar", "baz", "xyz", "zyx" }, Grapple)
        add({ "foo" }, Grapple) -- toggle
        same(icon .. "  1  2  3  4 ", Grapple.statusline())
    end)
    it("displays the name of a tag", function()
        local Grapple = require("grapple")
        add({ "foo", "bar" }, Grapple)
        vim.cmd.edit("foo")
        Grapple.tag({ name = "foo" })
        same(icon .. " [foo] 2 ", Grapple.statusline())
    end)
end)

describe("Statusline .format default", function()
    before_each(unload)
    it("does not display an icon when option include_icon = false", function()
        local Grapple = require("grapple")
        Grapple.setup({ statusline = { include_icon = false } })
        add({ "foo", "bar" }, Grapple)
        same(" 1 [2]", Grapple.statusline())
    end)
    it("correctly displays quickselect characters", function()
        local Grapple = require("grapple")
        Grapple.setup({ quick_select = "jklh56789" })
        add({ "foo", "bar", "baz", "xyz", "zyx" }, Grapple)
        vim.cmd.edit("bar")
        same(icon .. "  j [k] l  h  5 ", Grapple.statusline())
    end)
    it("correctly skips displaying quickselect characters", function()
        local Grapple = require("grapple")
        Grapple.setup({ quick_select = false })
        add({ "foo", "bar" }, Grapple)
        same(icon .. "  1 [2]", Grapple.statusline())
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
        vim.cmd.edit("bar")
        same("2", Grapple.statusline())
    end)
    it("is correct having 5 tags, current buffer is not tagged", function()
        local Grapple = require("grapple")
        add({ "foo", "bar", "baz", "xyz", "zyx" }, Grapple)
        vim.cmd.edit("abc")
        same("", Grapple.statusline())
    end)
    it("is correct when a tag is untagged", function()
        local Grapple = require("grapple")
        add({ "foo", "bar", "baz", "xyz", "zyx" }, Grapple)
        add({ "foo" }, Grapple)
        same("", Grapple.statusline())
    end)
    it("displays the name of a tag", function()
        local Grapple = require("grapple")
        add({ "foo", "bar" }, Grapple)
        vim.cmd.edit("foo")
        Grapple.tag({ name = "foo" })
        same("foo", Grapple.statusline())
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
    }
    if data.scope_name == "git" then
        data.scope_name = ""
    end

    local status = {} -- build slots:
    local max_tags = #data.tags
    local current_path = data.current and data.current.path or nil
    for i = 1, opts.max_slots do
        local tag_fmt = opts.inactive
        local tag_str = "" .. i
        if i > max_tags then -- more slots then ...
            tag_str = opts.empty_slot
        else
            local tag = data.tags[i]
            if current_path == tag.path then
                tag_fmt = opts.active
            end
        end
        table.insert(status, string.format(tag_fmt, tag_str))
    end
    if max_tags > opts.max_slots then -- more marks then... One indicator
        local tag_fmt = opts.inactive
        local tag_str = opts.more_marks_indicator
        if current_path then
            for i = opts.max_slots + 1, max_tags do
                local tag = data.tags[i]
                if current_path == tag.path then
                    tag_fmt = opts.active
                    break
                end
            end
        end
        table.insert(status, string.format(tag_fmt, tag_str))
    end

    local prefix = string.format("%s%s%s", opts_in.icon, data.scope_name == "" and "" or " ", data.scope_name)
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
        vim.cmd.edit("bar")
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
        vim.cmd.edit("abc")
        same(icon .. " 1234…", Grapple.statusline())
    end)
end)

describe("Api is_current_buffer_tagged", function()
    before_each(unload)
    it("correctly reports if the current buffer is tagged", function()
        local Grapple = require("grapple")
        local line = require("grapple.statusline").get()
        add({ "foo" }, Grapple)
        same(true, line:is_current_buffer_tagged())
        add({ "foo" }, Grapple)
        same(false, line:is_current_buffer_tagged())
    end)
end)
