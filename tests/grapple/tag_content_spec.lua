local TagContent = require("grapple.tag_content")

describe("TagContent", function()
    describe(".minimum_column", function()
        local test_cases = {
            -- ID only
            { 5, "/000 /some_path" },
            { 5, "/000 " },

            -- ID + icon
            { 9, "/001  /some_path" },
            { 9, "/001  " },

            -- ID + icon + name
            { 13, "/001  bob /some_path" },
            { 13, "/001  bob " },
        }

        for _, test_case in ipairs(test_cases) do
            local expected = test_case[1]
            local line = test_case[2]

            it(string.format("line %s, min_col %d", line, expected), function()
                assert.same(expected, TagContent:new(nil, nil, nil, nil):minimum_column(line))
            end)
        end
    end)
end)
