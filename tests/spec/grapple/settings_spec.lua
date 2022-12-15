describe("settings", function()
    it("has correct default", function()
        local path = require("grapple.path")
        local settings = require("grapple.settings")
        assert.equals("warn", settings.log_level)
        assert.equals("git", settings.scope)
        assert.equals(path.append(vim.fn.stdpath("data"), "grapple"), settings.save_path)

        assert.equals("editor", settings.popup_options.relative)
        assert.equals(60, settings.popup_options.width)
        assert.equals(12, settings.popup_options.height)
        assert.equals("minimal", settings.popup_options.style)
        assert.equals(false, settings.popup_options.focusable)
        assert.equals("single", settings.popup_options.border)

        assert.equals(false, settings.integrations.resession)
    end)

    describe("#update", function()
        it("overrides the correct settings", function()
            require("grapple.settings").update({
                log_level = "debug",
                scope = "static",
            })

            assert.equals("debug", require("grapple.settings").log_level)
            assert.equals("static", require("grapple.settings").scope)
        end)
    end)
end)
