local Path = require("plenary.path")
local with = require("plenary.context_manager").with

local function tag_state()
    return {
        project_one = {
            file_one = {
                file_path = "file_one",
                cursor = { 1, 1 },
            },
        },
        project_two = {
            file_two = {
                file_path = "file_two",
                cursor = { 2, 2 },
            },
        },
        none = {
            file_three = {
                file_path = "file_three",
                cursor = { 3, 3 },
            },
        },
        project_three = {},
    }
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

describe("", function()
    describe("#prune", function()
        it("removes files that are are associated with an empty sub-state", function()
            with(temp_dir(), function(dir_path)
                local state = tag_state()
                require("grapple.state").save(state, dir_path)

                state.project_one = {}
                require("grapple.state").prune(state, dir_path)

                assert.is_nil(require("grapple.state").load("project_one", dir_path))
            end)
        end)

        it("does not remove files that are are associated with a non-empty sub-state", function()
            with(temp_dir(), function(dir_path)
                local state = tag_state()
                require("grapple.state").save(state, dir_path)

                state.project_one = {}
                require("grapple.state").prune(state, dir_path)

                assert.is_not_nil(require("grapple.state").load("project_two", dir_path))
            end)
        end)
    end)

    describe("#save", function()
        it("saves table state as separate files", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(tag_state(), dir_path)
                assert.equals(2, #files(dir_path))
                assert.is_true(vim.tbl_contains(files(dir_path), "project%5Fone"))
                assert.is_true(vim.tbl_contains(files(dir_path), "project%5Ftwo"))
            end)
        end)

        it("does not save the 'none' sub-table", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(tag_state(), dir_path)
                assert.is_false(vim.tbl_contains(files(dir_path)), "none")
            end)
        end)

        it("does not save empty sub-tables", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(tag_state(), dir_path)
                assert.is_false(vim.tbl_contains(files(dir_path)), "project%5Fthree")
            end)
        end)
    end)

    describe("#load", function()
        it("loads a sub-state for a given state key", function()
            with(temp_dir(), function(dir_path)
                require("grapple.state").save(tag_state(), dir_path)
                local project_one = require("grapple.state").load("project_one", dir_path)
                assert.equals("file_one", project_one.file_one.file_path)
                assert.equals(1, project_one.file_one.cursor[1])
                assert.equals(1, project_one.file_one.cursor[2])
            end)
        end)

        it("returns nothing when a state key does not exist", function()
            with(temp_dir(), function(dir_path)
                assert.is_nil(require("grapple.state").load("project_infinity", dir_path))
            end)
        end)

        it("does not error when a state key does not exist", function()
            with(temp_dir(), function(dir_path)
                local ok, _ = pcall(require("grapple.state").load, "project_infinity", dir_path)
                assert.is_true(ok)
            end)
        end)
    end)

    describe("#migrate", function()
        it("migrates the old grapple.json to the new save structure", function()
            with(temp_dir(), function(dir_path)
                local old_save_path = Path:new(dir_path) / "grapple.json"
                local new_save_path = Path:new(dir_path) / "grapple"

                old_save_path:write(vim.json.encode(tag_state()), "w")
                require("grapple.state").migrate(old_save_path, old_save_path, new_save_path)

                assert.is_true(vim.tbl_contains(files(tostring(new_save_path)), "project%5Fone"))
                assert.is_true(vim.tbl_contains(files(tostring(new_save_path)), "project%5Ftwo"))

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
