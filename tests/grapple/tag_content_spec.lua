local App = require("grapple.app")
local TagContent = require("grapple.tag_content")

local function content(icons)
    local app = App:new()
    app:update({ icons = icons })

    return TagContent:new(
        app,
        assert(app:current_scope()),
        app.settings.tag_hook,
        app.settings.tag_title,
        app.settings.styles["relative"]
    )
end

describe("TagContent", function()
    describe(".minimum_column", function()
        describe("with icons", function()
            local test_cases = {
                { 9, "/101  /some_path" },
                { 9, "/102  /some_path" },
                { 9, "/103  /some_path" },
                { 9, "/104  " },
                { 9, "/105            " },
            }

            for _, test_case in ipairs(test_cases) do
                local expected = test_case[1]
                local line = test_case[2]

                it(string.format('expected col %d, line "%s"', expected, line), function()
                    assert.same(expected, content(true):minimum_column(line))
                end)
            end
        end)

        describe("without icons", function()
            local test_cases = {
                -- No ID
                { 0, "" },
                { 0, "/some_path" },

                -- Malformed ID
                { 0, "/001/some_path" },
                { 0, "001" },
                { 0, "/a /some_path" },
                { 0, "/0 /some_path" },
                { 0, "/00 /some_path" },

                -- ID only
                { 5, "/000 /some_path" },
                { 5, "/000 " },
                { 5, "/000           " },
                { 5, "/000           /some_path" },

                -- Whitespace in file path
                { 5, "/000 /some_path with spaces" },
            }

            for _, test_case in ipairs(test_cases) do
                local expected = test_case[1]
                local line = test_case[2]

                it(string.format('expected col %d, line "%s"', expected, line), function()
                    assert.same(expected, content(false):minimum_column(line))
                end)
            end
        end)
    end)
end)
