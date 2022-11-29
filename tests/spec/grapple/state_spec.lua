local Path = require("plenary.path")
local with = require("plenary.context_manager").with

local function test_resolvers()
    require("grapple.scope").static("project_one", { key = "project_one" })
    require("grapple.scope").static("project_two", { key = "project_two" })
    require("grapple.scope").static("project_three", { key = "project_three", persist = false })
    require("grapple.scope").static("project_four", { key = "project_four" })
    require("grapple.scope").static("project_five", { key = "project_five" })
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

    describe("#migrate", function()
        it("migrates the old grapple.json to the new save structure", function()
            with(temp_dir(), function(dir_path)
                local old_save_path = tostring(Path:new(dir_path) / "grapple.json")
                local new_save_path = tostring(Path:new(dir_path) / "grapple")

                Path:new(old_save_path):write(vim.json.encode(tag_state()), "w")
                require("grapple.state").migrate(old_save_path, old_save_path, new_save_path)

                assert.is_true(vim.tbl_contains(files(new_save_path), "project%5Fone"))
                assert.is_true(vim.tbl_contains(files(new_save_path), "project%5Ftwo"))

                local project_one = require("grapple.state").load("project_one", new_save_path)
                assert.equals("file_one", project_one.file_one.file_path)
                assert.equals(1, project_one.file_one.cursor[1])
                assert.equals(1, project_one.file_one.cursor[2])

                local project_two = require("grapple.state").load("project_two", new_save_path)
                assert.equals("file_two", project_two.file_two.file_path)
                assert.equals(2, project_two.file_two.cursor[1])
                assert.equals(2, project_two.file_two.cursor[2])
            end)
        end)
    end)
end)
