describe("grapple", function()
    before_each(function()
        require("grapple").reset()
    end)

    describe("#tag", function()
        it("creates a tag for the current buffer", function()
            require("grapple").tag({ scope = "none" })
            assert.is_true(require("grapple").exists({ scope = "none" }), "tag should exist")
        end)

        it("does not create a tag in a different scope", function()
            require("grapple").tag({ scope = "none" })
            assert.is_false(require("grapple").exists({ scope = "git" }), "tag should not exist")
        end)
    end)

    describe("#untag", function()
        it("removes a tag on the current buffer", function()
            require("grapple").tag({ scope = "none" })
            require("grapple").untag({ scope = "none" })
            assert.is_false(require("grapple").exists({ scope = "none" }), "tag should not exist")
        end)
    end)

    describe("#toggle", function()
        it("creates a tag on the current buffer when it does not exist", function()
            require("grapple").toggle({ scope = "none" })
            assert.is_true(require("grapple").exists({ scope = "none" }), "tag should exist")
        end)

        it("removes a tag on the current buffer when it does exist", function()
            require("grapple").tag({ scope = "none" })
            require("grapple").toggle({ scope = "none" })
            assert.is_false(require("grapple").exists({ scope = "none" }), "tag not should exist")
        end)
    end)

    describe("#exists", function() end)
    describe("#cycle", function() end)

    describe("#tags", function()
        it("returns the list of tags", function()
            require("grapple").tag({ key = "bob", scope = "none" })
            assert.equals("bob", require("grapple").tags("none")[1].key)
            assert.equals(1, #require("grapple").tags("none"))
        end)
    end)
end)
