local Path = require("plenary.path")

local buffer_unnamed = vim.fn.bufnr()

local buffer_one = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buffer_one, "one")
vim.api.nvim_win_set_buf(0, buffer_one)

local dir_path = Path:new("/private/tmp") / string.gsub(vim.fn.tempname(), "%p", "")
local file_two = dir_path / "two"
local cursor_two = { 1, 5 }
dir_path:mkdir()
file_two:write("one small favour", "w")

local function test_resolvers()
    require("grapple.scope").reset()
    require("grapple.scope").static("scope", { key = "scope", persist = false })
    require("grapple.scope").static("other_scope", { key = "other_scope", persist = false })
end

describe("tags", function()
    before_each(function()
        test_resolvers()
        vim.api.nvim_win_set_buf(0, buffer_unnamed)
        require("grapple.tags").reset("scope")
        require("grapple.tags").reset("scope")
    end)

    describe("#tag", function()
        it("creates a tag for a given buffer", function()
            require("grapple.tags").tag("scope", { buffer = 0 })
            assert.not_nil(require("grapple.tags").find("scope", { buffer = 0 }))
        end)

        it("does not create duplicate tags for the same buffer", function()
            require("grapple.tags").tag("scope", { buffer = buffer_one })
            require("grapple.tags").tag("scope", { buffer = buffer_one })
            assert.equals(1, require("grapple.tags").count("scope"))
        end)

        it("does not create duplicate tags for the same file path", function()
            require("grapple.tags").tag("scope", { file_path = file_two })
            require("grapple.tags").tag("scope", { file_path = file_two })
            assert.equals(1, require("grapple.tags").count("scope"))
        end)
    end)

    describe("#untag", function()
        it("removes a tag on a given buffer", function()
            require("grapple.tags").tag("scope", { buffer = buffer_one })
            require("grapple.tags").untag("scope", { buffer = buffer_one })
            assert.is_nil(require("grapple.tags").find("scope", { buffer = buffer_one }))
        end)
    end)

    describe("#update", function()
        it("updates a tags cursor location", function()
            local tag = require("grapple.tags").tag("scope", { buffer = buffer_one })

            require("grapple.tags").update("scope", tag, { 10, 11 })
            tag = require("grapple.tags").find("scope", { buffer = buffer_one })

            assert.equals(10, tag.cursor[1])
            assert.equals(11, tag.cursor[2])
        end)
    end)

    describe("#select", function()
        it("selects an open buffer", function()
            local tag = require("grapple.tags").tag("scope", { buffer = buffer_one })
            require("grapple.tags").select(tag)
            assert.equals(buffer_one, vim.api.nvim_win_get_buf(0))
            assert.equals(1, vim.api.nvim_win_get_cursor(0)[1])
            assert.equals(0, vim.api.nvim_win_get_cursor(0)[2])
        end)

        it("selects an unopen file path", function()
            local tag = require("grapple.tags").tag("scope", { file_path = file_two })
            require("grapple.tags").update("scope", tag, cursor_two)

            tag = require("grapple.tags").find("scope", { file_path = file_two })
            require("grapple.tags").select(tag)

            assert.equals(tostring(file_two), vim.api.nvim_buf_get_name(0))
            assert.equals(cursor_two[1], vim.api.nvim_win_get_cursor(0)[1])
            assert.equals(cursor_two[2], vim.api.nvim_win_get_cursor(0)[2])
        end)
    end)

    describe("#find", function()
        it("finds a tag for a given buffer", function()
            require("grapple.tags").tag("scope", { buffer = buffer_one })
            assert.not_nil(require("grapple.tags").find("scope", { buffer = buffer_one }))
        end)

        it("finds a tag for a given file path", function()
            require("grapple.tags").tag("scope", { file_path = file_two })
            assert.not_nil(require("grapple.tags").find("scope", { file_path = file_two }))
        end)

        it("finds a tag for a given tag key", function()
            require("grapple.tags").tag("scope", { buffer = buffer_one, key = "one" })
            assert.not_nil(require("grapple.tags").find("scope", { key = "one" }))
        end)

        it("does not return a tag when the tag does not exist", function()
            require("grapple.tags").tag("scope", { buffer = buffer_one, key = "one" })
            assert.is_nil(require("grapple.tags").find("scope", { key = "blah" }))
        end)
    end)

    describe("#count", function()
        it("returns the number of tags in a tag scope", function()
            require("grapple.tags").tag("scope", { buffer = 0 })
            assert.equals(1, require("grapple.tags").count("scope"))
        end)
    end)

    describe("#quickfix", function()
        it("populates the quickfix list for a given scope", function()
            require("grapple.tags").tag("scope", { buffer = buffer_one })
            require("grapple.tags").quickfix("scope")
            assert.equals(1, vim.fn.getqflist({ size = 1 }).size)

            local quickfix_list = vim.fn.getqflist()
            assert.equals(buffer_one, quickfix_list[1].bufnr)
            assert.equals(1, quickfix_list[1].lnum)
            assert.equals(1, quickfix_list[1].col)
            assert.equals(" [1] ", quickfix_list[1].text)
        end)

        it("does not populate the quickfix list with other scope tags", function()
            require("grapple.tags").tag("other_scope", { buffer = 0 })
            require("grapple.tags").quickfix("scope")
            assert.equals(0, vim.fn.getqflist({ size = 1 }).size)
        end)

        it("opens the quickfix list", function()
            require("grapple.tags").tag("scope", { buffer = 0 })
            require("grapple.tags").quickfix("scope")
            assert.not_equals(0, vim.fn.getqflist({ qfbufnr = 1 }).qfbufnr)
        end)
    end)
end)
