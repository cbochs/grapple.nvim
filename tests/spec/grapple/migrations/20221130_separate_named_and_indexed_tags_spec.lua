local Path = require("plenary.path")
local with = require("plenary.context_manager").with

local function test_resolvers()
    require("grapple.scope").static("project_one", { key = "project_one" })
    require("grapple.scope").static("project_two", { key = "project_two" })
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

describe("20221130_separate_named_and_indexed_tags", function()
    before_each(function()
        test_resolvers()
    end)

    describe("#migrate", function()
        it("migrates and separates named tags and indexed tags in the save file", function()
            with(temp_dir(), function(dir_path)
                for scope, scope_state in pairs(test_state_table()) do
                    local save_path = Path:new(dir_path) / require("grapple.state").encode(scope)
                    save_path:write(vim.json.encode(scope_state), "w")
                end
                require("grapple.migrations.20221130_separate_named_and_indexed_tags").migrate(dir_path)

                assert.is_true(vim.tbl_contains(files(dir_path), "project%5Fone"))
                assert.is_true(vim.tbl_contains(files(dir_path), "project%5Ftwo"))

                for scope, _ in pairs(test_state_table()) do
                    local save_path = Path:new(dir_path) / require("grapple.state").encode(scope)
                    local scope_state = vim.json.decode(save_path:read())
                    assert.not_nil(scope_state.__indexed)
                end

                for scope, _ in pairs(test_state_table()) do
                    local scope_state = require("grapple.state").load(scope, dir_path)
                    assert.not_nil(scope_state[1])
                end
            end)
        end)
    end)
end)
