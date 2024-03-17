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

            -- ID + name
            { 9, "/001 bob /some_path" },
            { 9, "/002 bob bob" },
            { 9, "/003 bob      bob  " },
            { 9, "/004 bob " },
            { 7, "/005 a /some_path" },
            { 7, "/006 a " },
            { 7, "/007 a           " },

            -- ID + icon
            { 9, "/001  /some_path" },
            { 9, "/002  /some_path" },
            { 9, "/003  /some_path" },
            { 9, "/004  " },
            { 9, "/005            " },

            -- ID + icon + name
            { 13, "/001  bob /some_path" },
            { 13, "/002  bob " },
            { 11, "/003  c /some_path" },
            { 11, "/004  c " },
            { 11, "/005  c           " },

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
