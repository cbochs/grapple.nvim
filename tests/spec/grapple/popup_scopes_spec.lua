local basic_resolver = require("grapple.scope").static("scope_basic", { persist = false })
local other_resolver = require("grapple.scope").static("scope_other", { persist = false })

local function test_state()
    local state = require("grapple.state")
    local basic_scope = state.ensure_loaded(basic_resolver)
    state.set(basic_scope, {})
    state.set(basic_scope, {})

    local other_scope = state.ensure_loaded(other_resolver)
    state.set(other_scope, {})
end

describe("popup_scopes", function()
    before_each(function()
        test_state()
    end)

    after_each(function()
        require("grapple.state").reset()
    end)

    describe("#serialize", function()
        it("serializes a scope with its tag count", function()
            local scope = require("grapple.state").ensure_loaded(basic_resolver)
            assert.equals(" [2] scope_basic", require("grapple.popup_scopes").handler.serialize(nil, scope))
        end)
    end)

    describe("#deserialize", function()
        it("parses a line with a scope", function()
            local scope = require("grapple.state").ensure_loaded(basic_resolver)
            local line = require("grapple.popup_scopes").handler.serialize(nil, scope)
            assert.equals(scope, require("grapple.popup_scopes").handler.deserialize(nil, line))
        end)
    end)

    describe("#resolve_differences", function()
        it("identifies no changes", function()
            local original_scopes = require("grapple.state").scopes()
            local modified_scopes = original_scopes
            require("grapple.popup_scopes").resolve_differences(original_scopes, modified_scopes)

            local basic_scope = require("grapple.scope").get(basic_resolver)
            assert.equals(2, require("grapple.state").count(basic_scope))

            local other_scope = require("grapple.scope").get(other_resolver)
            assert.equals(1, require("grapple.state").count(other_scope))
        end)

        it("identifies a deleted scope", function()
            local original_scopes = require("grapple.state").scopes()
            local modified_scopes = {
                require("grapple.scope").get(other_resolver),
            }
            require("grapple.popup_scopes").resolve_differences(original_scopes, modified_scopes)

            local other_scope = require("grapple.scope").get(other_resolver)
            assert.equals(1, require("grapple.state").count(other_scope))
        end)
    end)
end)
