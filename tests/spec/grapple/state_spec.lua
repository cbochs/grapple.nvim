local Path = require("plenary.path")
local with = require("plenary.context_manager").with

local resolvers = {
    project_one = require("grapple.scope").static("project_one_scope"),
    project_two = require("grapple.scope").static("project_two_scope"),
    project_three = require("grapple.scope").static("project_three_scope", { persist = false }),
    project_four = require("grapple.scope").static("project_four_scope"),
    project_five = require("grapple.scope").static("project_five_scope"),
    random = require("grapple.scope").suffix(
        require("grapple.scope").resolver(function()
            return tostring(math.random(1, 100))
        end, { cache = false }),
        require("grapple.scope").resolver(function()
            return tostring(math.random(1, 100))
        end, { cache = false })
    ),
}

local function test_state()
    local state = require("grapple.state")
    state.set(resolvers.project_one, { file_path = "file_one" })
    state.set(resolvers.project_one, { file_path = "file_two" }, "keyed_tag")
    state.set(resolvers.project_two, { file_path = "" })
    state.set(resolvers.project_three, { file_path = "" })
    state.ensure_loaded(resolvers.project_four)
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

    after_each(function()
        require("grapple.state").reset()
    end)

    describe("#save", function()
        it("saves state as separate files", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                assert.equals(2, #files(dir_path))
                assert.is_true(vim.tbl_contains(files(dir_path), "project%5Fone%5Fscope"))
                assert.is_true(vim.tbl_contains(files(dir_path), "project%5Ftwo%5Fscope"))
            end)
        end)

        it("does not save state for non-persistent scopes", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                assert.is_false(vim.tbl_contains(files(dir_path)), "project%5Fthree%5Fscope")
            end)
        end)

        it("does not save state for empty scopes", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                assert.is_false(vim.tbl_contains(files(dir_path)), "project%5Ffour%5Fscope")
            end)
        end)
    end)

    describe("#load", function()
        it("loads scope state for a given scope resolver", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                local scope = require("grapple.scope").get(resolvers.project_one)
                local project_one = require("grapple.state").load(scope, dir_path)
                assert.equals("file_one", project_one[1].file_path)
                assert.equals("file_two", project_one.keyed_tag.file_path)
            end)
        end)

        it("returns nothing when a scope does not exist", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                local scope = require("grapple.scope").get(resolvers.project_five)
                assert.is_nil(require("grapple.state").load(scope, dir_path))
            end)
        end)
    end)

    describe("#prune", function()
        it("removes files that are are associated with an empty sub-state", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                require("grapple.state").unset(resolvers.project_two, 1)
                require("grapple.state").prune(dir_path)

                local scope = require("grapple.scope").get(resolvers.project_two)
                assert.is_nil(require("grapple.state").load(scope, dir_path))
            end)
        end)

        it("does not remove files that are are associated with a non-empty sub-state", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)

                require("grapple.state").unset(resolvers.project_one, "file_one")
                require("grapple.state").prune(dir_path)

                local scope = require("grapple.scope").get(resolvers.project_two)
                assert.is_not_nil(require("grapple.state").load(scope, dir_path))
            end)
        end)
    end)

    describe("#get", function()
        it("returns the state item associated with a scope key", function()
            local item = require("grapple.state").get(resolvers.project_one, "keyed_tag")
            assert.equals("file_two", item.file_path)
        end)

        it("can handle a wildly varying scope resolver", function()
            for _ = 1, 1000 do
                local ok, scope = pcall(require("grapple.state").scope, resolvers.random)
                assert.is_true(ok)
                assert.is_table(scope)
            end
        end)
    end)

    describe("#set", function()
        it("sets a state item to a given key", function()
            require("grapple.state").set(resolvers.project_one, 1, "my key")
            assert.equals(1, require("grapple.state").get(resolvers.project_one, "my key"))
        end)
    end)

    describe("#commit", function()
        it("commits a list of changes in order", function()
            local actions = {
                require("grapple.state").actions.set({ file_path = "file_one" }, "one"),
                require("grapple.state").actions.set({ file_path = "file_two" }, "two"),
                require("grapple.state").actions.unset("one"),
                require("grapple.state").actions.move("two", "one"),
            }
            local scope_state = require("grapple.state").commit(resolvers.project_five, actions)
            assert.equals("file_two", scope_state.one.file_path)
        end)
    end)

    describe("#exists", function()
        it("returns true when a state item exists", function()
            assert.is_true(require("grapple.state").exists(resolvers.project_one, "keyed_tag"))
        end)

        it("returns false when a state item exists", function()
            assert.is_false(require("grapple.state").exists(resolvers.project_one, "asdf"))
        end)
    end)

    describe("#key", function()
        it("returns the key of a state item", function()
            assert.equals("keyed_tag", require("grapple.state").key(resolvers.project_one, { file_path = "file_two" }))
        end)

        it("return nil when the state item does not exist", function()
            assert.is_nil(require("grapple.state").key(resolvers.project_one, { file_path = "file_three" }))
        end)
    end)

    describe("#keys", function()
        it("returns the keys for a given scope", function()
            local keys = require("grapple.state").keys(resolvers.project_one)
            assert.equals(2, #keys)
            assert.is_true(vim.tbl_contains(keys, 1))
            assert.is_true(vim.tbl_contains(keys, "keyed_tag"))
        end)
    end)

    describe("#scopes", function()
        it("returns all the loaded scopes", function()
            local scopes = require("grapple.state").scopes()
            assert.equals(4, #scopes)
            assert.is_true(vim.tbl_contains(scopes, "project_one_scope"))
            assert.is_true(vim.tbl_contains(scopes, "project_two_scope"))
            assert.is_true(vim.tbl_contains(scopes, "project_three_scope"))
            assert.is_true(vim.tbl_contains(scopes, "project_four_scope"))
        end)
    end)

    describe("#scope", function()
        it("returns all the items in a given scope", function()
            local state_items = require("grapple.state").scope(resolvers.project_one)
            assert.is_table(state_items)
            assert.not_nil(state_items[1])
            assert.not_nil(state_items.keyed_tag)
        end)
    end)

    describe("#count", function()
        it("returns the number of items in a given scope", function()
            assert(2, require("grapple.state").count(resolvers.project_one))
        end)
    end)

    describe("#scope_pairs", function()
        it("returns a list of (scope, scope_resolver) pairs", function()
            local scope_pairs = require("grapple.state").scope_pairs()
            assert.equals(4, #scope_pairs)
            for _, scope_pair in pairs(scope_pairs) do
                assert.not_nil(scope_pair.scope)
                assert.not_nil(scope_pair.resolver)
            end
        end)
    end)

    describe("#resolver", function()
        it("returns a scope resolver for a given scope", function()
            local resolver = require("grapple.state").resolver("project_one_scope")
            assert.equals("project_one_scope", require("grapple.scope").get(resolver))
        end)
    end)

    describe("#state", function()
        it("returns the entire state", function()
            local state_ = require("grapple.state").state()
            assert.not_nil(state_.project_one_scope)
            assert.not_nil(state_.project_two_scope)
            assert.not_nil(state_.project_three_scope)
            assert.not_nil(state_.project_four_scope)
            assert.is_nil(state_.project_five_scope)
        end)
    end)

    describe("#load_all", function()
        it("loads the entire state", function()
            local state_ = require("grapple.state").state()
            require("grapple.state").reset()
            require("grapple.state").load_all(state_)
            assert.not_nil(state_.project_one_scope)
            assert.not_nil(state_.project_two_scope)
            assert.not_nil(state_.project_three_scope)
            assert.not_nil(state_.project_four_scope)
            assert.is_nil(state_.project_five_scope)
        end)
    end)

    describe("#reset", function()
        it("resets a scope state to an empty table", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                require("grapple.state").reset(resolvers.project_one)
                assert.equals(0, #vim.tbl_keys(require("grapple.state").scope(resolvers.project_one)))
                assert.not_nil(require("grapple.state").resolver("project_one_scope"))
            end)
        end)
    end)
end)
