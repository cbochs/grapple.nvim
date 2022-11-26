local Path = require("plenary.path")

local function test_resolvers()
    require("grapple.scope").resolver(function()
        return "__basic__"
    end, { key = "basic", cache = true })

    require("grapple.scope").resolver(function()
        return "__basic__"
    end, { key = "basic_uncached", cache = false })

    require("grapple.scope").resolver(function()
        return "__basic__"
    end, { key = "basic_autocmd", cache = "DirChanged" })

    local counter = 0
    require("grapple.scope").resolver(function()
        counter = counter + 1
        return tostring(counter)
    end, { key = "cached_counter", cache = true })

    require("grapple.scope").resolver(function()
        return nil
    end, { key = "bad_nil" })

    require("grapple.scope").resolver(function()
        return { this = "is", a = "table" }
    end, { key = "bad_malformed" })

    require("grapple.scope").resolver(function()
        error("im patrick")
    end, { key = "bad_error" })
end

describe("scope", function()
    after_each(function()
        require("grapple.scope").reset()
    end)

    describe("#get", function()
        before_each(function()
            test_resolvers()
        end)

        it("accepts a scope resolver key as input", function()
            assert.equals("__basic__", require("grapple.scope").get("basic"))
        end)

        it("accepts a scope resolver as input", function()
            local basic = require("grapple.scope").resolvers.basic
            assert.equals("__basic__", require("grapple.scope").get(basic))
        end)

        it("gets a scope path that has not been cached", function()
            require("grapple.scope").invalidate("basic")
            assert.equals("__basic__", require("grapple.scope").get("basic"))
        end)

        it("gets a scope path that has been cached", function()
            require("grapple.scope").get("cached_counter")
            assert.equals("1", require("grapple.scope").get("cached_counter"))
        end)

        it("errors when the scope resolver does not exist", function()
            local ok, _ = pcall(require("grapple.scope").get, "not a scope key")
            assert.is_false(ok)
        end)

        it("errors when the scope resolver is not valid", function()
            local not_a_resolver = function() end
            local ok, _ = pcall(require("grapple.scope").get, not_a_resolver)
            assert.is_false(ok)
        end)
    end)

    describe("#update", function()
        before_each(function()
            test_resolvers()
        end)

        it("returns the resolved scope path", function()
            assert.equals("__basic__", require("grapple.scope").update("basic"))
        end)

        it("caches a caching scope resolver", function()
            require("grapple.scope").update("basic")
            assert.is_true(require("grapple.scope").cached("basic"))
        end)

        it("caches an autocmd caching scope resolver", function()
            require("grapple.scope").update("basic_autocmd")
            assert.is_true(require("grapple.scope").cached("basic_autocmd"))
        end)

        it("does not cache a non-caching scope resolver", function()
            require("grapple.scope").update("basic_uncached")
            assert.is_false(require("grapple.scope").cached("basic_uncached"))
        end)

        it("creates an autocmd for the first time a scope is resolved", function()
            local basic_autocmd = require("grapple.scope").resolvers.basic_autocmd
            require("grapple.scope").update(basic_autocmd)

            local autocmd_ids = vim.tbl_map(function(autocmd)
                return autocmd.id
            end, vim.api.nvim_get_autocmds({ group = "GrappleScope" }))

            assert.not_nil(basic_autocmd.autocmd)
            assert.is_true(vim.tbl_contains(autocmd_ids, basic_autocmd.autocmd))
        end)

        it("does not recreate the autocmd for a scope resolver", function()
            local basic_autocmd = require("grapple.scope").resolvers.basic_autocmd

            require("grapple.scope").update(basic_autocmd)
            local first_autocmd_id = basic_autocmd.autocmd

            require("grapple.scope").update(basic_autocmd)
            local second_autocmd_id = basic_autocmd.autocmd

            assert.equals(first_autocmd_id, second_autocmd_id)
        end)
    end)

    describe("#resolve", function()
        before_each(function()
            test_resolvers()
        end)

        it("resolves to a scope path", function()
            local scope_resolver = require("grapple.scope").resolvers.basic
            assert.equals("__basic__", require("grapple.scope").resolve(scope_resolver.resolve))
        end)

        it("does not resolve when the scope path is nil", function()
            local scope_resolver = require("grapple.scope").resolvers.bad_nil
            assert.is_nil(require("grapple.scope").resolve(scope_resolver.resolve))
        end)

        it("does not resolve when the scope path is not a string", function()
            local scope_resolver = require("grapple.scope").resolvers.bad_malformed
            assert.is_nil(require("grapple.scope").resolve(scope_resolver.resolve))
        end)

        it("does not resolve when the resolver errors", function()
            local scope_resolver = require("grapple.scope").resolvers.bad_error
            assert.is_nil(require("grapple.scope").resolve(scope_resolver.resolve))
        end)
    end)

    describe("#invalidate", function()
        before_each(function()
            test_resolvers()
        end)

        it("clears the cache for a scope resolver", function()
            require("grapple.scope").get("cached_counter")
            require("grapple.scope").invalidate("cached_counter")
            assert.equals("2", require("grapple.scope").get("cached_counter"))
        end)

        it("clears the cache for a scope resolver with an autocmd", function() end)
    end)

    describe("#resolver", function()
        before_each(function()
            require("grapple.scope").reset()
        end)

        it("creates a default scope resolver", function()
            local foo = function() end
            local resolver = require("grapple.scope").resolver(foo)
            assert.is_table(resolver)
            assert.equals(1, resolver.key)
            assert.equals(foo, resolver.resolve)
            assert.equals(true, resolver.cache)
            assert.equals(nil, resolver.autocmd)
        end)

        it("appends the scope resolver when no key is given", function()
            local resolver = require("grapple.scope").resolver(function() end)
            assert.equals(1, resolver.key)
        end)

        it("creates a key for the scope resolver when a key is given", function()
            local resolver = require("grapple.scope").resolver(function() end, { key = "test" })
            assert.equals("test", resolver.key)
        end)

        it("creates a cached scope resolver", function()
            local resolver = require("grapple.scope").resolver(function() end, { cache = true })
            assert.equals(true, resolver.cache)
        end)

        it("creates a cached scope resolver with an autocmd", function()
            local resolver = require("grapple.scope").resolver(function() end, { cache = "DirChanged" })
            assert.equals("DirChanged", resolver.cache)
        end)

        it("creates a non-cached scope resolver", function()
            local resolver = require("grapple.scope").resolver(function() end, { cache = false })
            assert.equals(false, resolver.cache)
        end)
    end)

    describe("#root", function()
        before_each(function()
            require("grapple.scope").reset()
        end)

        it("creates a root scope resolver", function()
            local resolver = require("grapple.scope").root(".git")
            assert.is_table(resolver)
            assert.equals("DirChanged", resolver.cache)
        end)

        it("resolves a scope path when a root file exists", function()
            local root_dir = vim.fn.getcwd()
            local root_file = Path:new(root_dir) / "some_file"
            root_file:touch()

            local resolver = require("grapple.scope").root("some_file")
            assert.equals(root_dir, require("grapple.scope").get(resolver))

            root_file:rm()
        end)

        it("does not resolve a scope path when no root files are present", function()
            local resolver = require("grapple.scope").root("some_file")
            assert.is_nil(require("grapple.scope").get(resolver))
        end)
    end)

    describe("#fallback", function()
        before_each(function()
            test_resolvers()
        end)

        it("resolves a scope path in the fallback order", function()
            local resolver = require("grapple.scope").fallback({ "bad_nil", "basic", "cached_counter" })
            assert.equals("__basic__", require("grapple.scope").get(resolver))
            assert.is_true(require("grapple.scope").cached("basic"))
            assert.is_false(require("grapple.scope").cached("cached_counter"))
            assert.is_false(require("grapple.scope").cached(resolver))
        end)
    end)

    describe("builtin", function()
        before_each(function()
            require("grapple.scope_resolvers").create()
        end)

        -- stylua: ignore start
        local default_scopes = {
            { key = "none",      cache = true,  path = "__none__" },
            { key = "global",    cache = true,  path = "__global__" },
            { key = "static",    cache = true,  path = vim.fn.getcwd() },
            { key = "directory", cache = true,  path = vim.fn.getcwd() },
            { key = "git",       cache = false, path = vim.fn.getcwd() },
            { key = "lsp",       cache = false, path = vim.fn.getcwd() },
        }
        -- stylua: ignore end
        for _, scope in ipairs(default_scopes) do
            describe(scope.key, function()
                it(string.format("resolves a scope path", scope.key), function()
                    assert.equals(scope.path, require("grapple.scope").get(scope.key))
                end)

                local test_prefix = scope.cache and "caches" or "does not cache"
                it(string.format("%s the scope path", test_prefix, scope.key), function()
                    require("grapple.scope").get(scope.key)
                    assert.equals(scope.cache, require("grapple.scope").cached(scope.key))
                end)
            end)
        end
    end)
end)
