local scope = "none"
local other_scope = "global"

describe("tags", function()
    before_each(function()
        require("grapple.tags").reset(scope)
        require("grapple.tags").reset(other_scope)
    end)

    after_each(function()
        require("grapple.tags").reset(scope)
        require("grapple.tags").reset(other_scope)
    end)

    describe("#quickfix", function()
        it("populates the quickfix list for a given scope", function()
            require("grapple.tags").tag(scope, { buffer = 0 })
            require("grapple.tags").quickfix(scope)
            assert.equals(1, vim.fn.getqflist({ size = 1 }).size)

            local quickfix_list = vim.fn.getqflist()
            assert.equals(0, quickfix_list[1].bufnr)
            assert.equals(1, quickfix_list[1].lnum)
            assert.equals(1, quickfix_list[1].col)
            assert.equals(" [1] ", quickfix_list[1].text)
        end)

        it("does not populate the quickfix list with other scope tags", function()
            require("grapple.tags").tag(other_scope, { buffer = 0 })
            require("grapple.tags").quickfix(scope)
            assert.equals(0, vim.fn.getqflist({ size = 1 }).size)
        end)

        it("opens the quickfix list", function()
            require("grapple.tags").tag(scope, { buffer = 0 })
            require("grapple.tags").quickfix(scope)
            assert.not_equals(0, vim.fn.getqflist({ qfbufnr = 1 }).qfbufnr)
        end)
    end)
end)
