local Path = require("plenary.path")
local with = require("plenary.context_manager").with

local function test_resolvers()
    require("grapple.scope").static("project_one", { key = "project_one" })
    require("grapple.scope").static("project_two", { key = "project_two" })
    require("grapple.scope").static("project_three", { key = "project_three", persist = false })
    require("grapple.scope").static("project_four", { key = "project_four" })
    require("grapple.scope").static("project_five", { key = "project_five" })
end

local function test_state_table()
    return {
        project_one = {
            { file_path = "file_one" },
            keyed_tag = { file_path = "file_two" },
        },
        project_two = {
            { file_path = "file_one" },
        },
        project_three = {
            { file_path = "file_one" },
        },
        project_four = {},
    }
end

local function test_state()
    test_resolvers()

    local state = require("grapple.state")
    state.set("project_one", { file_path = "file_one" })
    state.set("project_one", { file_path = "file_two" }, "keyed_tag")
    state.set("project_two", { file_path = "" })
    state.set("project_three", { file_path = "" })
    state.get("project_four", "touch to create table")
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
                assert.is_true(vim.tbl_contains(files(dir_path), "project%5Fone"))
                assert.is_true(vim.tbl_contains(files(dir_path), "project%5Ftwo"))
            end)
        end)

        it("does not save state for non-persistent scopes", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                assert.is_false(vim.tbl_contains(files(dir_path)), "project%5Fthree")
            end)
        end)

        it("does not save state for empty scopes", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                assert.is_false(vim.tbl_contains(files(dir_path)), "project%5Ffour")
            end)
        end)
    end)

    describe("#load", function()
        it("loads scope state for a given scope resolver", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                local project_one = require("grapple.state").load("project_one", dir_path)
                assert.equals("file_one", project_one[1].file_path)
                assert.equals("file_two", project_one.keyed_tag.file_path)
            end)
        end)

        it("returns nothing when a state key does not exist", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                assert.is_nil(require("grapple.state").load("project_five", dir_path))
            end)
        end)

        it("does not error when a state key does not exist", function()
            with(temp_dir(), function(dir_path)
                local ok, _ = pcall(require("grapple.state").load, "project_five", dir_path)
                assert.is_true(ok)
            end)
        end)
    end)

    describe("#prune", function()
        it("removes files that are are associated with an empty sub-state", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)
                require("grapple.state").unset("project_two", 1)
                require("grapple.state").prune(dir_path)

                assert.is_nil(require("grapple.state").load("project_two", dir_path))
            end)
        end)

        it("does not remove files that are are associated with a non-empty sub-state", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(dir_path)

                require("grapple.state").unset("project_one", "file_one")
                require("grapple.state").prune(dir_path)

                assert.is_not_nil(require("grapple.state").load("project_two", dir_path))
            end)
        end)
    end)

    describe("#get", function()
        it("returns the state item associated with a scope key", function()
            local item = require("grapple.state").get("project_one", "keyed_tag")
            assert.equals("file_two", item.file_path)
        end)
    end)

    describe("#set", function()
        it("sets a state item to a given key", function()
            require("grapple.state").set("project_one", 1, "my key")
            assert.equals(1, require("grapple.state").get("project_one", "my key"))
        end)
    end)

    describe("#exists", function()
        it("returns true when a state item exists", function()
            assert.is_true(require("grapple.state").exists("project_one", "keyed_tag"))
        end)

        it("returns false when a state item exists", function()
            assert.is_false(require("grapple.state").exists("project_one", "asdf"))
        end)
    end)

    describe("#query", function()
        it("returns the key of a state item", function()
            assert.equals("keyed_tag", require("grapple.state").query("project_one", { file_path = "file_two" }))
        end)

        it("return nil when the state item does not exist", function()
            assert.is_nil(require("grapple.state").query("project_one", { file_path = "file_three" }))
        end)
    end)

    describe("#keys", function()
        it("returns the keys for a given scope", function()
            local keys = require("grapple.state").keys("project_one")
            assert.equals(2, #keys)
            assert.is_true(vim.tbl_contains(keys, 1))
            assert.is_true(vim.tbl_contains(keys, "keyed_tag"))
        end)
    end)

    describe("#scopes", function()
        it("returns all the loaded scopes", function()
            local scopes = require("grapple.state").scopes()
            assert.equals(4, #scopes)
            assert.is_true(vim.tbl_contains(scopes, "project_one"))
            assert.is_true(vim.tbl_contains(scopes, "project_two"))
            assert.is_true(vim.tbl_contains(scopes, "project_three"))
            assert.is_true(vim.tbl_contains(scopes, "project_four"))
        end)
    end)

    describe("#scope", function()
        it("returns all the items in a given scope", function()
            local state_items = require("grapple.state").scope("project_one")
            assert.is_table(state_items)
            assert.not_nil(state_items[1])
            assert.not_nil(state_items.keyed_tag)
        end)
    end)

    describe("#count", function()
        it("returns the number of items in a given scope", function()
            assert(2, require("grapple.state").count("project_one"))
        end)
    end)

    describe("#state", function()
        it("returns the entire state", function()
            local state_ = require("grapple.state").state()
            assert.not_nil(state_.project_one)
            assert.not_nil(state_.project_two)
            assert.not_nil(state_.project_three)
            assert.not_nil(state_.project_four)
            assert.is_nil(state_.project_five)
        end)
    end)

    describe("#load_all", function()
        it("loads the entire state", function()
            local state_ = require("grapple.state").state()
            require("grapple.state").reset()
            require("grapple.state").load_all(state_)
            assert.not_nil(state_.project_one)
            assert.not_nil(state_.project_two)
            assert.not_nil(state_.project_three)
            assert.not_nil(state_.project_four)
            assert.is_nil(state_.project_five)
        end)
    end)

    describe("#migrate", function()
        it("migrates the old grapple.json to the new save structure", function()
            with(temp_dir(), function(dir_path)
                local old_save_path = tostring(Path:new(dir_path) / "grapple.json")
                local new_save_path = tostring(Path:new(dir_path) / "grapple")

                Path:new(old_save_path):write(vim.json.encode(test_state_table()), "w")
                require("grapple.state").migrate(old_save_path, old_save_path, new_save_path)

                assert.is_true(vim.tbl_contains(files(new_save_path), "project%5Fone"))
                assert.is_true(vim.tbl_contains(files(new_save_path), "project%5Ftwo"))

                local project_one = require("grapple.state").load("project_one", new_save_path)
                -- vim.pretty_print(project_one)
                assert.equals("file_one", project_one[1].file_path)
                assert.equals("file_two", project_one.keyed_tag.file_path)

                local project_two = require("grapple.state").load("project_two", new_save_path)
                assert.equals("file_one", project_two[1].file_path)
            end)
        end)
    end)
end)
