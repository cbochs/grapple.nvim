local Path = require("plenary.path")
local with = require("plenary.context_manager").with

local resolvers = {
    basic = require("grapple.scope").static("scope_basic"),
    indexed = require("grapple.scope").static("scope_indexed"),
    mixed = require("grapple.scope").static("scope_mixed", { persist = false }),
    no_persist = require("grapple.scope").static("scope_no_persist", { persist = false }),
    empty = require("grapple.scope").static("scope_empty"),
}

local function test_state()
    local state = require("grapple.state")

    local basic = state.ensure_loaded(resolvers.basic)
    state.set(basic, { file_path = "basic_file" }, "some_key")

    local indexed = state.ensure_loaded(resolvers.indexed)
    state.set(indexed, { file_path = "indexed_file" })

    local mixed = state.ensure_loaded(resolvers.mixed)
    state.set(mixed, { file_path = "mixed_file_one" })
    state.set(mixed, { file_path = "mixed_file_two" }, "some_key")

    local no_persist = state.ensure_loaded(resolvers.no_persist)
    state.set(no_persist, { file_path = "" })

    state.ensure_loaded(resolvers.empty)
end

local function files(dir_path)
    local file_names = {}
    for file_name, _ in vim.fs.dir(dir_path) do
        table.insert(file_names, file_name)
    end
    return file_names
end

local function temp_dir()
    local dir_path = Path:new(vim.fn.tempname())
    dir_path:mkdir()

    return coroutine.create(function()
        coroutine.yield(dir_path:absolute())
        dir_path:rmdir()
    end)
end

describe("state", function()
    before_each(function()
        test_state()
    end)

    after_each(function()
        require("grapple.state").reset()
    end)

    describe("#save", function()
        it("saves state as separate files", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                assert.equals(2, #files(dir_path))
                vim.pretty_print(files(dir_path))
                assert.is_true(vim.tbl_contains(files(dir_path), "scope%5Fbasic"))
                assert.is_true(vim.tbl_contains(files(dir_path), "scope%5Findexed"))
            end)
        end)

        it("does not save state for non-persistent scopes", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                assert.is_false(vim.tbl_contains(files(dir_path)), "scope%5Fno%5Fpersist")
            end)
        end)

        it("does not save state for empty scopes", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                assert.is_false(vim.tbl_contains(files(dir_path)), "scope%5Fempty%5F")
            end)
        end)
    end)

    describe("#load", function()
        it("loads a scope with keyed items", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                local scope = require("grapple.scope").get(resolvers.basic)
                local scope_state = require("grapple.state").load(scope, dir_path)
                assert.equals("basic_file", scope_state.some_key.file_path)
            end)
        end)

        it("loads a scope with indexed items", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                local scope = require("grapple.scope").get(resolvers.indexed)
                local scope_state = require("grapple.state").load(scope, dir_path)
                assert.equals("indexed_file", scope_state[1].file_path)
            end)
        end)

        it("returns nothing when a scope does not exist", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                local scope = require("grapple.scope").get(resolvers.empty)
                assert.is_nil(require("grapple.state").load(scope, dir_path))
            end)
        end)
    end)

    describe("#prune", function()
        it("removes files that are are associated with an empty sub-state", function()
            with(temp_dir(), function(dir_path)
                local scope = require("grapple.scope").get(resolvers.basic)
                require("grapple.state").save(dir_path)
                require("grapple.state").unset(scope, "some_key")
                require("grapple.state").prune(dir_path)
                assert.is_nil(require("grapple.state").load(scope, dir_path))
            end)
        end)

        it("does not remove files that are are associated with a non-empty sub-state", function()
            with(temp_dir(), function(dir_path)
                local scope = require("grapple.scope").get(resolvers.basic)
                require("grapple.state").save(dir_path)
                require("grapple.state").prune(dir_path)
                assert.is_not_nil(require("grapple.state").load(scope, dir_path))
            end)
        end)
    end)

    describe("#get", function()
        it("returns the state item associated with a scope key", function()
            local scope = require("grapple.state").ensure_loaded(resolvers.basic)
            local item = require("grapple.state").get(scope, "some_key")
            assert.equals("basic_file", item.file_path)
        end)
    end)

    describe("#set", function()
        it("sets a state item to a given key", function()
            local scope = require("grapple.state").ensure_loaded(resolvers.basic)
            require("grapple.state").set(scope, 1, "some_key")
            assert.equals(1, require("grapple.state").get(scope, "some_key"))
        end)
    end)

    describe("#exists", function()
        it("returns true when a state item exists", function()
            local scope = require("grapple.state").ensure_loaded(resolvers.basic)
            assert.is_true(require("grapple.state").exists(scope, "some_key"))
        end)

        it("returns false when a state item exists", function()
            local scope = require("grapple.state").ensure_loaded(resolvers.basic)
            assert.is_false(require("grapple.state").exists(scope, "asdf"))
        end)
    end)

    describe("#key", function()
        it("returns the key of a state item", function()
            local scope = require("grapple.state").ensure_loaded(resolvers.basic)
            assert.equals("some_key", require("grapple.state").key(scope, { file_path = "basic_file" }))
        end)

        it("return nil when the state item does not exist", function()
            local scope = require("grapple.state").ensure_loaded(resolvers.basic)
            assert.is_nil(require("grapple.state").key(scope, { file_path = "lol_not_a_file" }))
        end)
    end)

    describe("#keys", function()
        it("returns the keys for a given scope", function()
            local scope = require("grapple.state").ensure_loaded(resolvers.mixed)
            local keys = require("grapple.state").keys(scope)
            assert.equals(2, #keys)
            assert.is_true(vim.tbl_contains(keys, 1))
            assert.is_true(vim.tbl_contains(keys, "some_key"))
        end)
    end)

    describe("#scopes", function()
        it("returns all the loaded scopes", function()
            local scopes = require("grapple.state").scopes()
            assert.equals(5, #scopes)
            assert.is_true(vim.tbl_contains(scopes, "scope_basic"))
            assert.is_true(vim.tbl_contains(scopes, "scope_indexed"))
            assert.is_true(vim.tbl_contains(scopes, "scope_mixed"))
            assert.is_true(vim.tbl_contains(scopes, "scope_no_persist"))
            assert.is_true(vim.tbl_contains(scopes, "scope_empty"))
        end)
    end)

    describe("#scope", function()
        it("returns all the items in a given scope", function()
            local scope = require("grapple.state").ensure_loaded(resolvers.mixed)
            local state_items = require("grapple.state").scope(scope)
            assert.is_table(state_items)
            assert.not_nil(state_items[1])
            assert.not_nil(state_items.some_key)
        end)
    end)

    describe("#count", function()
        it("returns the number of items in a given scope", function()
            local scope = require("grapple.state").ensure_loaded(resolvers.mixed)
            assert(2, require("grapple.state").count(scope))
        end)
    end)

    describe("#scope_pairs", function()
        it("returns a list of (scope, scope_resolver) pairs", function()
            local scope_pairs = require("grapple.state").scope_pairs()
            assert.equals(5, #scope_pairs)
            for _, scope_pair in pairs(scope_pairs) do
                assert.not_nil(scope_pair.scope)
                assert.not_nil(scope_pair.resolver)
            end
        end)
    end)

    describe("#resolver", function()
        it("returns a scope resolver for a given scope", function()
            local resolver = require("grapple.state").resolver("scope_basic")
            assert.equals(resolvers.basic, resolver)
        end)
    end)

    describe("#state", function()
        it("returns the entire state", function()
            local state_ = require("grapple.state").state()
            assert.not_nil(state_.scope_basic)
            assert.not_nil(state_.scope_indexed)
            assert.not_nil(state_.scope_mixed)
            assert.not_nil(state_.scope_no_persist)
            assert.not_nil(state_.scope_empty)
            assert.is_nil(state_.scope_nope)
        end)
    end)

    describe("#load_all", function()
        it("loads the entire state", function()
            local state_ = require("grapple.state").state()
            require("grapple.state").reset()
            require("grapple.state").load_all(state_)
            assert.not_nil(state_.scope_basic)
            assert.not_nil(state_.scope_indexed)
            assert.not_nil(state_.scope_mixed)
            assert.not_nil(state_.scope_no_persist)
            assert.not_nil(state_.scope_empty)
            assert.is_nil(state_.scope_nope)
        end)
    end)

    describe("#reset", function()
        it("resets the state of a given scope", function()
            local scope = require("grapple.state").ensure_loaded(resolvers.basic)
            require("grapple.state").reset(scope)
            assert.equals(0, #require("grapple.state").keys(scope))
            assert.equals(resolvers.basic, require("grapple.state").resolver(scope))
        end)

        it("resets the entire state", function()
            require("grapple.state").reset()
            assert.equals(0, #vim.tbl_keys(require("grapple.state").state()))
        end)
    end)
end)
