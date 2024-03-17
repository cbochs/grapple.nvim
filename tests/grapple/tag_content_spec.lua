local TagContent = require("grapple.tag_content")

describe("TagContent", function()
    describe(".minimum_column", function()
        local test_cases = {
            -- ID only
            { 5, "/000 /some_path" },
            { 5, "/000 " },
            { 5, "/000           " },
            { 5, "/000           /some_path" },

            -- ID + name
            { 9, "/001 bob /some_path" },
            { 9, "/001 bob bob" },
            { 9, "/001 bob      bob  " },
            { 9, "/001 bob " },
            { 7, "/001 a /some_path" },
            { 7, "/001 a " },
            { 7, "/001 a           " },

            -- ID + icon
            { 9, "/001  /some_path" },
            { 9, "/002  /some_path" },
            { 9, "/003  /some_path" },
            { 9, "/004  " },
            { 9, "/005            " },

            -- ID + icon + name
            { 13, "/001  bob /some_path" },
            { 13, "/001  bob " },
            { 11, "/001  c /some_path" },
            { 11, "/001  c " },
            { 11, "/001  c           " },

            -- Assumed behaviour (last part editable)
            { 16, "/000 /some_path /another_path" },
        }

        for _, test_case in ipairs(test_cases) do
            local expected = test_case[1]
            local line = test_case[2]

            it(string.format('expected col %d, line "%s"', expected, line), function()
                assert.same(expected, TagContent:new(nil, nil, nil, nil):minimum_column(line))
            end)
        end
    end)
end)
