local Grapple = require("grapple")

---@diagnostic disable-next-line: undefined-field
local same = assert.same
-- local icon = "󰛢"

describe("Statusline", function()
    describe(".format", function()
        it("has correct default behaviour", function()
            same("", Grapple.statusline())
        end)
    end)
end)
