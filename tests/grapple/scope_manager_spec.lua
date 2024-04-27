local ScopeManager = require("grapple.scope_manager")
local Util = require("grapple.util")

describe("TagContent", function()
    describe(".list", function()
        it("returns a list of scopes, sorted by name", function()
            local sm = ScopeManager:new()
            sm:define("c", function() end)
            sm:define("b", function() end)
            sm:define("a", function() end)
            assert.are.same({ "a", "b", "c" }, vim.tbl_map(Util.pick("name"), sm:list()))
        end)
    end)
end)