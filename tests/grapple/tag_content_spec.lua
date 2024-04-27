local App = require("grapple.app")
local TagContent = require("grapple.tag_content")

describe("TagContent", function()
    describe(".minimum_column", function()
        local test_cases = {
            -- No ID or invalid ID
            { 0, "" },
            { 0, "/some_path" },
            { 0, "/001/some_path" },
            { 0, "001" },

            -- Partial ID
            { 3, "/0 /some_path" },
            { 4, "/00 /some_path" },

            -- ID only
            { 5, "/000 /some_path" },
            { 5, "/000 " },
            { 5, "/000           " },
            { 5, "/000           /some_path" },

            -- Assumed behaviour (last part editable)
            { 5, "/000 /some_path /another_path" },
        }

        for _, test_case in ipairs(test_cases) do
            local expected = test_case[1]
            local line = test_case[2]

            it(string.format('expected col %d, line "%s"', expected, line), function()
                local empty = function() end
                local app = App:new()
                app:update({ scope = "global", icons = false })

                assert.is_same(
                    expected,
                    TagContent:new(app, assert(app:current_scope()), empty, empty, empty):minimum_column(line)
                )
            end)
        end

        local test_cases_icons = {
            -- ID + icon
            { 9, "/001  /some_path" },
            { 9, "/002  /some_path" },
            { 9, "/003  /some_path" },
            { 9, "/004  " },
            { 9, "/005            " },
        }

        for _, test_case in ipairs(test_cases_icons) do
            local expected = test_case[1]
            local line = test_case[2]

            it(string.format('expected col %d, line "%s"', expected, line), function()
                local empty = function() end
                local app = App:new()
                app:update({ scope = "global", icons = true })
                assert.is_same(
                    expected,
                    TagContent:new(app, assert(app:current_scope()), empty, empty, empty):minimum_column(line)
                )
            end)
        end
    end)
end)
