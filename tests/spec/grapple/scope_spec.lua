local Path = require("plenary.path")

local counter = 0
local resolvers = {
    basic = require("grapple.scope").resolver(function()
        return "__basic__"
    end, { persist = false }),

    basic_uncached = require("grapple.scope").resolver(function()
        return "__basic__"
    end, { persist = false, cache = false }),

    basic_autocmd = require("grapple.scope").resolver(function()
        return "__basic__"
    end, { persist = false, cache = "DirChanged" }),

    counter_cached = require("grapple.scope").resolver(function()
        counter = counter + 1
        return tostring(counter)
    end, { persist = false }),

    random = require("grapple.scope").resolver(function()
        return tostring(math.random(1, 100))
    end, { cache = false, persist = false }),

    bad_nil = require("grapple.scope").resolver(function()
        return nil
    end, { persist = false }),

    bad_malformed = require("grapple.scope").resolver(function()
        return { this = "is", a = "table" }
    end, { persist = false }),

    bad_error = require("grapple.scope").resolver(function()
        error("im patrick")
    end, { persist = false }),
}

describe("scope", function()
    after_each(function()
        counter = 0
        require("grapple.scope").reset()
    end)

    describe("#get", function()
        it("accepts a scope key for a builtin scope resolver", function()
            assert.equals("__none__", require("grapple.scope").get("none"))
        end)

        it("accepts a scope resolver as input", function()
            assert.equals("__basic__", require("grapple.scope").get(resolvers.basic))
        end)

        it("gets a scope that has not been cached", function()
            require("grapple.scope").invalidate(resolvers.basic)
            assert.equals("__basic__", require("grapple.scope").get(resolvers.basic))
        end)

        it("gets a scope that has been cached", function()
            require("grapple.scope").get(resolvers.counter_cached)
            assert.equals("1", require("grapple.scope").get(resolvers.counter_cached))
        end)

        it("errors when the scope key is not a builtin scope resolver", function()
            local ok, _ = pcall(require("grapple.scope").get, "not a builtin")
            assert.is_false(ok)
        end)

        it("errors when the scope resolver is not valid", function()
            local not_a_resolver = function() end
            local ok, _ = pcall(require("grapple.scope").get, not_a_resolver)
            assert.is_false(ok)
        end)
    end)

    describe("#invalidate", function()
        it("clears the cache for a scope resolver", function()
            local resolver = resolvers.counter_cached
            require("grapple.scope").get(resolver)
            require("grapple.scope").invalidate(resolver)
            assert.equals("2", require("grapple.scope").get(resolver))
        end)

        it("clears the cache for a scope resolver with an autocmd", function() end)
    end)

    describe("#update", function()
        it("returns the resolved scope", function()
            assert.equals("__basic__", require("grapple.scope").update(resolvers.basic))
        end)

        it("caches a caching scope resolver", function()
            require("grapple.scope").update(resolvers.basic)
            assert.is_true(require("grapple.scope").cached(resolvers.basic))
        end)

        it("caches an autocmd caching scope resolver", function()
            require("grapple.scope").update(resolvers.basic_autocmd)
            assert.is_true(require("grapple.scope").cached(resolvers.basic_autocmd))
        end)

        it("does not cache a non-caching scope resolver", function()
            require("grapple.scope").update(resolvers.basic_uncached)
            assert.is_false(require("grapple.scope").cached(resolvers.basic_uncached))
        end)

        it("creates an autocmd for the first time a scope is resolved", function()
            local resolver = resolvers.basic_autocmd
            require("grapple.scope").update(resolver)

            local autocmd_ids = vim.tbl_map(function(autocmd)
                return autocmd.id
            end, vim.api.nvim_get_autocmds({ group = "GrappleScope" }))

            assert.not_nil(resolver.autocmd)
            assert.is_true(vim.tbl_contains(autocmd_ids, resolver.autocmd))
        end)

        it("does not recreate the autocmd for a scope resolver", function()
            local resolver = resolvers.basic_autocmd

            require("grapple.scope").update(resolver)
            local first_autocmd_id = resolver.autocmd

            require("grapple.scope").update(resolver)
            local second_autocmd_id = resolver.autocmd

            assert.equals(first_autocmd_id, second_autocmd_id)
        end)
    end)

    describe("#resolve", function()
        it("resolves to a scope", function()
            assert.equals("__basic__", require("grapple.scope").resolve(resolvers.basic))
        end)

        it("does not resolve when the scope is nil", function()
            assert.is_nil(require("grapple.scope").resolve(resolvers.bad_nil))
        end)

        it("does not resolve when the scope is not a string", function()
            assert.is_nil(require("grapple.scope").resolve(resolvers.bad_malformed))
        end)

        it("does not resolve when the resolver errors", function()
            assert.is_nil(require("grapple.scope").resolve(resolvers.bad_error))
        end)
    end)

    describe("#scope_parts", function()
        it("returns all components in a scope", function()
            local parts = require("grapple.scope").scope_parts("one#two")
            assert.equals(2, #parts)
            assert.equals("one", parts[1])
            assert.equals("two", parts[2])
        end)
    end)

    describe("#resolver", function()
        before_each(function()
            require("grapple.scope").reset()
        end)

        it("creates a default scope resolver", function()
            local foo = function() end
            local resolver = require("grapple.scope").resolver(foo)
            assert.is_table(resolver)
            assert.is_number(resolver.key)
            assert.equals(foo, resolver.resolve)
            assert.equals(true, resolver.cache)
            assert.equals(true, resolver.persist)
            assert.equals(nil, resolver.autocmd)
        end)

        it("gives the scope resolver a unique id when no key is given", function()
            local resolver_one = require("grapple.scope").resolver(function() end)
            local resolver_two = require("grapple.scope").resolver(function() end)
            assert.not_equals(resolver_one.key, resolver_two.key)
            assert.equals(1, resolver_two.key - resolver_one.key)
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

        it("resolves a scope when a root file exists", function()
            local root_dir = vim.fn.getcwd()
            local root_file = Path:new(root_dir) / "some_file"
            root_file:touch()

            local resolver = require("grapple.scope").root("some_file")
            assert.equals(root_dir, require("grapple.scope").get(resolver))

            root_file:rm()
        end)

        it("does not resolve a scope when no root files are present", function()
            local resolver = require("grapple.scope").root("some_file")
            assert.is_nil(require("grapple.scope").get_safe(resolver))
        end)
    end)

    describe("#fallback", function()
        it("creates a fallback scope resolver", function()
            local resolver = require("grapple.scope").fallback({ resolvers.basic })
            assert.is_table(resolver)
            assert.equals(false, resolver.cache)
        end)

        it("resolves a scope in the fallback order", function()
            local resolver = require("grapple.scope").fallback({
                resolvers.bad_nil,
                resolvers.basic,
                resolvers.counter_cached,
            })

            assert.equals("__basic__", require("grapple.scope").get(resolver))
            assert.is_true(require("grapple.scope").cached(resolvers.basic))
            assert.is_false(require("grapple.scope").cached(resolvers.counter_cached))
        end)

        it("resolves nested fallback scopes", function()
            local resolver = require("grapple.scope").fallback({
                require("grapple.scope").fallback({ resolvers.bad_nil, resolvers.bad_error }),
                require("grapple.scope").fallback({ resolvers.basic }),
            })
            assert.equals("__basic__", require("grapple.scope").get(resolver))
        end)

        it("does not cache the scope", function()
            local resolver = require("grapple.scope").fallback({ resolvers.basic })
            require("grapple.scope").get(resolver)
            assert.is_false(require("grapple.scope").cached(resolver))
        end)
    end)

    describe("#suffix", function()
        it("creates a suffix scope resolver", function()
            local resolver = require("grapple.scope").suffix(resolvers.basic, resolvers.basic)
            assert.is_table(resolver)
            assert.equals(false, resolver.cache)
        end)

        it("resolves a scope with a suffix", function()
            local resolver = require("grapple.scope").suffix(resolvers.basic, resolvers.basic)
            assert.equals("__basic__#__basic__", require("grapple.scope").get(resolver))
        end)

        it("resolves a scope without a suffix", function()
            local resolver = require("grapple.scope").suffix(resolvers.basic, resolvers.bad_nil)
            assert.equals("__basic__", require("grapple.scope").get(resolver))
        end)

        it("resolves a scope for a varying suffix", function()
            local resolver = require("grapple.scope").suffix(resolvers.basic, resolvers.random)
            for _ = 1, 100 do
                local scope = require("grapple.scope").get(resolver)
                assert.equals(2, #require("grapple.scope").scope_parts(scope))
            end
        end)

        it("does not cache the scope", function()
            local resolver = require("grapple.scope").suffix(resolvers.basic, resolvers.basic)
            require("grapple.scope").get(resolver)
            assert.is_false(require("grapple.scope").cached(resolver))
        end)

        it("does not resolve when the scope path is nil", function()
            local resolver = require("grapple.scope").suffix(resolvers.bad_basic, resolvers.basic)
            assert.is_nil(require("grapple.scope").get_safe(resolver))
        end)
    end)

    describe("#static", function()
        it("creates a static scope resolver", function()
            local resolver = require("grapple.scope").static("asdf")
            assert.is_table(resolver)
        end)

        it("resolves a scope as a static string", function()
            local resolver = require("grapple.scope").static("asdf")
            assert.equals("asdf", require("grapple.scope").get(resolver))
        end)
    end)

    describe("builtin", function()
        -- stylua: ignore start
        local builtin_resolvers = {
            { key = "none",         cache = true,  expected_path = "__none__" },
            { key = "global",       cache = true,  expected_path = "__global__" },
            { key = "static",       cache = true,  expected_path = vim.fn.getcwd() },
            { key = "directory",    cache = true,  expected_path = vim.fn.getcwd() },
            { key = "git_fallback", cache = true,  expected_path = vim.fn.getcwd() },
            { key = "git",          cache = false, expected_path = vim.fn.getcwd() },
            { key = "lsp_fallback", cache = false, expected_path = nil },
            { key = "lsp",          cache = false, expected_path = vim.fn.getcwd() },
        }
        -- stylua: ignore end

        for _, resolver in ipairs(builtin_resolvers) do
            describe(resolver.key, function()
                it(string.format("resolves a scope", resolver.key), function()
                    assert.equals(resolver.expected_path, require("grapple.scope").get_safe(resolver.key))
                end)

                local test_prefix = resolver.cache and "caches" or "does not cache"
                it(string.format("%s the scope", test_prefix, resolver.key), function()
                    require("grapple.scope").get_safe(resolver.key)
                    assert.equals(resolver.cache, require("grapple.scope").cached(resolver.key))
                end)
            end)
        end
    end)
end)
