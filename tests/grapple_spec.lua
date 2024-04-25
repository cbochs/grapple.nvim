local Grapple = require("grapple")
local Helpers = require("tests.helpers")

-- TODO: this is not great, but a good smoke test for the refactor
local function assert_state(expected)
    assert.is_same(
        vim.tbl_deep_extend("keep", expected, {
            id = "test",
        }),
        Grapple.app().tag_manager.state:read("test")
    )
end

describe("Grapple", function()
    before_each(function()
        Grapple.setup({ save_path = Helpers.temp_dir })
        Grapple.define_scope({
            name = "test",
            cache = true,
            force = true,
            resolver = function()
                return "test", nil, nil
            end,
        })

        Grapple.use_scope("test", { notify = false })
        Grapple.reset({ scope = "test" })

        local buf_id1 = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(buf_id1, "/test1")

        local buf_id2 = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(buf_id2, "/test2")
    end)

    after_each(function()
        vim.api.nvim_buf_delete(vim.fn.bufnr("/test1"), { force = true })
        vim.api.nvim_buf_delete(vim.fn.bufnr("/test2"), { force = true })
    end)

    describe("Grapple.tag", function()
        it("works", function()
            assert.is_nil(Grapple.tag({ path = "/test" }))
            assert_state({ tags = { { path = "/test" } } })
        end)
    end)

    describe("Grapple.untag", function()
        it("works", function()
            assert.is_nil(Grapple.tag({ path = "/test" }))
            assert.is_nil(Grapple.untag({ path = "/test" }))
            assert_state({ tags = {} })
        end)
    end)

    describe("Grapple.toggle", function()
        it("works", function()
            assert.is_nil(Grapple.toggle({ path = "/test" }))
            assert_state({ tags = { { path = "/test" } } })

            assert.is_nil(Grapple.toggle({ path = "/test" }))
            assert_state({ tags = {} })
        end)
    end)

    describe("Grapple.select", function()
        it("works", function()
            vim.api.nvim_win_set_buf(0, vim.fn.bufnr("/test1", false))
            Grapple.tag({ path = "/test2" })

            assert.is_nil(Grapple.select({ path = "/test2" }))
            assert.is_same(vim.fn.bufnr("/test2", false), vim.api.nvim_get_current_buf())
        end)

        it("requires some input", function()
            assert.is_same("must provide a valid index, name, or path", Grapple.select())
        end)
    end)

    describe("Grapple.cycle_tags", function()
        before_each(function()
            vim.api.nvim_win_set_buf(0, vim.fn.bufnr("/test1", false))
            Grapple.tag({ path = "/test1" })
            Grapple.tag({ path = "/test2" })
        end)

        describe("next", function()
            it("works", function()
                assert.is_nil(Grapple.cycle_tags("next"))
                assert.is_same(vim.fn.bufnr("/test2", false), vim.api.nvim_get_current_buf())
                assert.is_nil(Grapple.cycle_tags("next"))
                assert.is_same(vim.fn.bufnr("/test1", false), vim.api.nvim_get_current_buf())
            end)
        end)

        describe("prev", function()
            it("works", function()
                assert.is_nil(Grapple.cycle_tags("prev"))
                assert.is_same(vim.fn.bufnr("/test2", false), vim.api.nvim_get_current_buf())
                assert.is_nil(Grapple.cycle_tags("prev"))
                assert.is_same(vim.fn.bufnr("/test1", false), vim.api.nvim_get_current_buf())
            end)
        end)
    end)

    describe("Grapple.touch", function()
        it("works", function()
            vim.api.nvim_win_set_buf(0, vim.fn.bufnr("/test1", false))
            Grapple.tag({ path = "/test1" })

            assert.is_nil(Grapple.touch())
            assert_state({ tags = {
                { path = "/test1", cursor = { 1, 0 } },
            } })
        end)
    end)

    describe("Grapple.find", function()
        it("works", function()
            Grapple.tag({ path = "/test1" })

            local tag, err = Grapple.find({ path = "/test1" })
            assert(tag)
            assert.is_nil(err)
            assert.is_same("/test1", tag.path)
        end)
    end)

    describe("Grapple.exists", function()
        it("works", function()
            Grapple.tag({ path = "/test1" })

            assert.is_true(Grapple.exists({ path = "/test1" }))
            assert.is_false(Grapple.exists({ path = "/test2" }))
        end)
    end)

    describe("Grapple.name_or_index", function()
        it("works", function()
            Grapple.tag({ path = "/test1" })
            Grapple.tag({ path = "/test2", name = "bob" })

            assert.is_same(1, Grapple.name_or_index({ path = "/test1" }))
            assert.is_same("bob", Grapple.name_or_index({ path = "/test2" }))
        end)
    end)

    describe("Grapple.tags", function()
        it("works", function()
            Grapple.tag({ path = "/test1" })
            Grapple.tag({ path = "/test2", name = "bob" })

            local tags, err = Grapple.tags()
            assert(tags)
            assert.is_nil(err)
            assert.is_same(tags[1].path, "/test1")
            assert.is_same(tags[2].path, "/test2")
        end)
    end)

    describe("Grapple.define_scope", function() end)
    describe("Grapple.delete_scope", function() end)
    describe("Grapple.use_scope", function() end)
    describe("Grapple.unload", function() end)
    describe("Grapple.reset", function() end)
    describe("Grapple.prune", function() end)
    describe("Grapple.quickfix", function() end)

    describe("Grapple.statusline", function()
        it("works", function()
            Grapple.tag({ path = "/test1" })
            Grapple.tag({ path = "/test2", name = "bob" })

            assert.is_same("󰛢  1  bob ", Grapple.statusline())
        end)
    end)
end)
