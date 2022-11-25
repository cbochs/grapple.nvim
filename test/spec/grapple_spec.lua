describe("grapple", function()
    before_each(function()
        require("grapple").setup({ scope = "none" })
        require("grapple").reset()
    end)

    describe("#tag", function()
        it("creates a tag for the current buffer", function()
            require("grapple").tag()
            assert.is_true(require("grapple").exists(), "tag shoud exist")
        end)
    end)

    describe("#untag", function()
        it("removes a tag on the current buffer", function()
            require("grapple").tag()
            require("grapple").untag()
            assert.is_false(require("grapple").exists(), "tag should not exist")
        end)
    end)

    describe("#toggle", function()
        it("creates a tag on the current buffer when it does not exist", function()
            require("grapple").toggle()
            assert.is_true(require("grapple").exists(), "tag shoud exist")
        end)

        it("removes a tag on the current buffer when it does exist", function()
            require("grapple").tag()
            require("grapple").toggle()
            assert.is_false(require("grapple").exists(), "tag not shoud exist")
        end)
    end)

    describe("#exists", function() end)
    describe("#cycle", function() end)
end)
