local TagContent = require("grapple.tag_content")

describe("TagContent", function()
    describe(".minimum_column", function()
        local test_cases = {
            -- No ID or invalid ID
            { 0, "", nil, false },
            { 0, "/some_path", nil, false },
            { 0, "/001/some_path", nil, false },
            { 0, "001", nil, false },

            -- Partial ID
            { 3, "/0 /some_path", nil, false },
            { 4, "/00 /some_path", nil, false },

            -- ID only
            { 5, "/000 /some_path", nil, false },
            { 5, "/000 ", nil, false },
            { 5, "/000           ", nil, false },
            { 5, "/000           /some_path", nil, false },

            -- ID + name
            { 9, "/001 bob /some_path", "bob", false },
            { 9, "/002 bob bob", "bob", false },
            { 9, "/003 bob      bob  ", "bob", false },
            { 9, "/004 bob ", "bob", false },
            { 7, "/005 a /some_path", "a", false },
            { 7, "/006 a ", "a", false },
            { 7, "/007 a           ", "a", false },

            -- ID + icon
            { 9, "/001  /some_path", nil, true },
            { 9, "/002  /some_path", nil, true },
            { 9, "/003  /some_path", nil, true },
            { 9, "/004  ", nil, true },
            { 9, "/005            ", nil, true },

            -- ID + icon + name
            { 13, "/001  bob /some_path", "bob", true },
            { 13, "/002  bob ", "bob", true },
            { 11, "/003  c /some_path", "c", true },
            { 11, "/004  c ", "c", true },
            { 11, "/005  c           ", "c", true },

            -- Paths and names with spaces
            { 19, "/001  bob alice /some_path", "bob alice", true },
            { 19, "/001  bob alice /some_path with_a_space", "bob alice", true },
            { 13, "/001  bob /some_path with_a_space", "bob", true },
            { 9, "/001 bob /some_path with_a_space", "bob", false },
        }

        local App = require("grapple.app")
        local app = App:get()
        ---@diagnostic disable-next-line: inject-field
        app.settings.name_pos = "start"

        for _, test_case in ipairs(test_cases) do
            local expected = test_case[1]
            local line = test_case[2]
            local name = test_case[3]
            local icons = test_case[4]

            ---@diagnostic disable-next-line: inject-field
            app.settings.icons = icons

            it(string.format('expected col %d, line "%s"', expected, line), function()
                assert.same(expected, TagContent:new(nil, nil, nil, nil):minimum_column(line, name))
            end)
        end
    end)
end)
