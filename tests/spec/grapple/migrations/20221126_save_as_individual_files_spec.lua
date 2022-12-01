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

describe("20221126_save_as_individual_files", function()
    before_each(function()
        test_resolvers()
    end)

    describe("#migrate", function()
        it("migrates the old grapple.json to the new save structure", function()
            with(temp_dir(), function(dir_path)
                local old_save_path = tostring(Path:new(dir_path) / "grapple.json")
                local new_save_path = tostring(Path:new(dir_path) / "grapple")

                Path:new(old_save_path):write(vim.json.encode(test_state_table()), "w")
                require("grapple.migrations.20221126_save_as_individual_files").migrate(
                    old_save_path,
                    old_save_path,
                    new_save_path
                )

                assert.is_true(vim.tbl_contains(files(new_save_path), "project%5Fone"))
                assert.is_true(vim.tbl_contains(files(new_save_path), "project%5Ftwo"))

                local project_one = require("grapple.state").load("project_one", new_save_path)
                assert.equals("file_one", project_one["1"].file_path)
                assert.equals("file_two", project_one.keyed_tag.file_path)

                local project_two = require("grapple.state").load("project_two", new_save_path)
                assert.equals("file_one", project_two[1].file_path)
            end)
        end)
    end)
end)
