local Helpers = require("tests.helpers")
local Path = require("grapple.path")

-- Re-evaluate path constants to run some Windows tests
if vim.env.GRAPPLE_OS == "windows" then
    Path.os = "windows"
    Path.windows = Path.os == "windows"
    Path.macos = Path.os == "macos"
    Path.linux = Path.os == "linux"
    Path.unix = Path.macos or Path.linux

    Path.separator = Path.windows and "\\" or "/"
    Path.double_separator = string.format("%s%s", Path.separator, Path.separator)
end

-- Reference: https://cs.opensource.google/go/go/+/master:src/path/filepath/path_test.go

describe("Path", function()
    describe(".clean", function()
        local clean_tests = {
            -- Already clean
            { "abc", "abc" },
            { "abc/def", "abc/def" },
            { "a/b/c", "a/b/c" },
            { ".", "." },
            { "..", ".." },
            { "../..", "../.." },
            { "../../abc", "../../abc" },
            { "/abc", "/abc" },
            { "/", "/" },

            -- Empty is current dir
            { "", "." },

            -- Remove trailing slash
            { "abc/", "abc" },
            { "abc/def/", "abc/def" },
            { "a/b/c/", "a/b/c" },
            { "./", "." },
            { "../", ".." },
            { "../../", "../.." },
            { "/abc/", "/abc" },

            -- Remove doubled slash
            { "abc//def//ghi", "abc/def/ghi" },
            { "abc//", "abc" },

            -- Remove . elements
            { "abc/./def", "abc/def" },
            { "/./abc/def", "/abc/def" },
            { "abc/.", "abc" },

            -- Remove .. elements
            { "abc/def/ghi/../jkl", "abc/def/jkl" },
            { "abc/def/../ghi/../jkl", "abc/jkl" },
            { "abc/def/..", "abc" },
            { "abc/def/../..", "." },
            { "/abc/def/../..", "/" },
            { "abc/def/../../..", ".." },
            { "/abc/def/../../..", "/" },
            { "abc/def/../../../ghi/jkl/../../../mno", "../../mno" },
            { "/../abc", "/abc" },
            { "a/../b:/../../c", "../c" },

            -- Combinations
            { "abc/./../def", "def" },
            { "abc//./../def", "def" },
            { "abc/../../././../def", "../../def" },
        }

        local clean_tests_nonwin = {
            -- Remove leading doubled slash
            { "//abc", "/abc" },
            { "///abc", "/abc" },
            { "//abc//", "/abc" },
        }

        local clean_tests_win = {
            { "c:", "c:." },
            { "c:\\", "c:\\" },
            { "c:\\abc", "c:\\abc" },
            { "c:abc\\..\\..\\.\\.\\..\\def", "c:..\\..\\def" },
            { "c:\\abc\\def\\..\\..", "c:\\" },
            { "c:\\..\\abc", "c:\\abc" },
            { "c:..\\abc", "c:..\\abc" },
            { "c:\\b:\\..\\..\\..\\d", "c:\\d" },
            { "\\", "\\" },
            { "/", "\\" },
            -- { ".\\c:", ".\\c:" },
            -- { ".\\c:\\foo", ".\\c:\\foo" },
            -- { ".\\c:foo", ".\\c:foo" },
        }

        local clean_test_cases
        if Path.windows then
            clean_test_cases = Helpers.tbl_join(clean_tests, clean_tests_win)
        else
            clean_test_cases = Helpers.tbl_join(clean_tests, clean_tests_nonwin)
        end

        for _, test_case in ipairs(clean_test_cases) do
            local path = test_case[1]
            local expected = test_case[2]

            if Path.windows then
                expected = Path.from_slash(expected)
            end

            it(string.format("path %s, expect %s", path, expected), function()
                assert.same(expected, Path.clean(path))
            end)
        end
    end)

    describe(".is_absolute", function()
        local is_absolute_tests = {
            { "", false },
            { "/", true },
            { "/usr/bin/gcc", true },
            { "..", false },
            { "/a/../bb", true },
            { ".", false },
            { "./", false },
            { "lala", false },
        }

        local is_absolute_win_tests = {
            { "C:\\", true },
            { "c\\", false },
            { "c::", false },
            { "c:", false },
            { "/", false },
            { "\\", false },
            { "\\Windows", false },
            { "c:a\\b", false },
            { "c:\\a\\b", true },
            { "c:/a/b", true },
            { "\\\\host\\share", true },
            { "\\\\host\\share\\", true },
            { "\\\\host\\share\\foo", true },
            { "//host/share/foo/bar", true },
            -- { "\\\\?\\a\\b\\c", true },
            -- { "\\??\\a\\b\\c", true },
        }

        local is_absolute_test_cases = {}
        if Path.windows then
            local is_absolute_tests_no_volume = vim.deepcopy(is_absolute_tests)
            vim.tbl_map(function(test_case)
                test_case[2] = false
            end, is_absolute_tests_no_volume)

            local is_absolute_tests_volume = vim.deepcopy(is_absolute_tests)
            vim.tbl_map(function(test_case)
                test_case[1] = "c:" .. test_case[1]
            end, is_absolute_tests_volume)

            -- stylua: ignore
            is_absolute_test_cases = Helpers.tbl_join(
                is_absolute_tests_no_volume,
                is_absolute_tests_volume,
                is_absolute_win_tests
            )
        else
            is_absolute_test_cases = is_absolute_tests
        end

        for _, test_case in ipairs(is_absolute_test_cases) do
            local path = test_case[1]
            local expected = test_case[2]

            it(string.format("path %s, expect %s", path, expected), function()
                assert.same(expected, Path.is_absolute(path))
            end)
        end
    end)

    describe(".absolute", function()
        local absolute_tests = {
            ".",
            "b",
            "b/",
            "../a",
            "../a/b",
            "../a/b/./c/../../.././a",
            "../a/b/./c/../../.././a/",
            "$",
            "$/.",
            "$/a/../a/b",
            "$/a/b/c/../../.././a",
            "$/a/b/c/../../.././a/",
        }

        -- Only test when the OS is actually Windows
        local os_is_windows = vim.uv.os_uname().version:match("Windows")
        if Path.windows and not os_is_windows then
            return print("SKIPPING TESTS .absolute")
        end

        before_each(function()
            Helpers.fs_mkdir("root")
            Helpers.fs_mkdir("root/a")
            Helpers.fs_mkdir("root/a/b")
            Helpers.fs_mkdir("root/a/b/c")
            Helpers.fs_cd("root/a")
        end)

        after_each(function()
            Helpers.fs_cd()
            Helpers.fs_rm("root", "rf")
        end)

        -- Non-Windows tests
        for _, test_case in ipairs(absolute_tests) do
            local root = Helpers.fs_path("root")
            local path = string.gsub(test_case, "%$", root)

            it(string.format("path %s", path), function()
                local expected_stat = assert(vim.uv.fs_stat(path))
                local absolute = Path.absolute(path)
                local stat = assert(vim.uv.fs_stat(absolute))

                assert.same(expected_stat.dev, stat.dev)
                assert.is_true(Path.is_absolute(absolute))
                assert.same(Path.clean(absolute), absolute)
            end)
        end
    end)

    describe(".is_local", function()
        local is_local_tests = {
            { "", false },
            { ".", true },
            { "..", false },
            { "../a", false },
            { "/", false },
            { "/a", false },
            { "/a/../..", false },
            { "a", true },
            { "a/../a", true },
            { "a/", true },
            { "a/.", true },
            { "a/./b/./c", true },
            { "a/../b:/../../c", false },
        }

        local is_local_tests_win = {
            { "\\", false },
            { "\\a", false },
            { "C:", false },
            { "C:\\a", false },
            { "..\\a", false },
            { "a/../c:", false },
        }

        local is_local_test_cases
        if Path.windows then
            is_local_test_cases = Helpers.tbl_join(is_local_tests, is_local_tests_win)
        else
            is_local_test_cases = is_local_tests
        end

        for _, test_case in ipairs(is_local_test_cases) do
            local path = test_case[1]
            local expected = test_case[2]

            it(string.format("path %s, expect %s", path, expected), function()
                assert.same(expected, Path.is_local(path))
            end)
        end
    end)

    describe(".relative", function()
        local relative_tests = {
            { "a/b", "a/b", "." },
            { "a/b/.", "a/b", "." },
            { "a/b", "a/b/.", "." },
            { "./a/b", "a/b", "." },
            { "a/b", "./a/b", "." },
            { "ab/cd", "ab/cde", "../cde" },
            { "ab/cd", "ab/c", "../c" },
            { "a/b", "a/b/c/d", "c/d" },
            { "a/b", "a/b/../c", "../c" },
            { "a/b/../c", "a/b", "../b" },
            { "a/b/c", "a/c/d", "../../c/d" },
            { "a/b", "c/d", "../../c/d" },
            { "a/b/c/d", "a/b", "../.." },
            { "a/b/c/d", "a/b/", "../.." },
            { "a/b/c/d/", "a/b", "../.." },
            { "a/b/c/d/", "a/b/", "../.." },
            { "../../a/b", "../../a/b/c/d", "c/d" },
            { "/a/b", "/a/b", "." },
            { "/a/b/.", "/a/b", "." },
            { "/a/b", "/a/b/.", "." },
            { "/ab/cd", "/ab/cde", "../cde" },
            { "/ab/cd", "/ab/c", "../c" },
            { "/a/b", "/a/b/c/d", "c/d" },
            { "/a/b", "/a/b/../c", "../c" },
            { "/a/b/../c", "/a/b", "../b" },
            { "/a/b/c", "/a/c/d", "../../c/d" },
            { "/a/b", "/c/d", "../../c/d" },
            { "/a/b/c/d", "/a/b", "../.." },
            { "/a/b/c/d", "/a/b/", "../.." },
            { "/a/b/c/d/", "/a/b", "../.." },
            { "/a/b/c/d/", "/a/b/", "../.." },
            { "/../../a/b", "/../../a/b/c/d", "c/d" },
            { ".", "a/b", "a/b" },
            { ".", "..", ".." },

            -- can't do purely lexically
            { "..", ".", "err" },
            { "..", "a", "err" },
            { "../..", "..", "err" },
            { "a", "/a", "err" },
            { "/a", "a", "err" },
        }

        local relative_tests_win = {
            { "C:a\\b\\c", "C:a/b/d", "..\\d" },
            { "C:\\", "D:\\", "err" },
            { "C:", "D:", "err" },
            { "C:\\Projects", "c:\\projects\\src", "src" },
            { "C:\\Projects", "c:\\projects", "." },
            { "C:\\Projects\\a\\..", "c:\\projects", "." },
        }

        local relative_test_cases = {}
        if Path.windows then
            relative_test_cases = Helpers.tbl_join(relative_tests, relative_tests_win)
        else
            relative_test_cases = relative_tests
        end

        -- Non-Windows tests
        for _, test_case in ipairs(relative_test_cases) do
            local base = test_case[1]
            local targ = test_case[2]
            local expected = test_case[3]

            if Path.windows then
                expected = Path.from_slash(expected)
            end

            if expected ~= "err" then
                it(string.format("base %s, targ %s, expect %s", base, targ, expected), function()
                    local relative, err = Path.relative(base, targ)
                    assert.same(expected, relative)
                    assert.is_nil(err)
                end)
            else
                it(string.format("base %s, targ %s, expect error", base, targ, expected), function()
                    local relative, err = Path.relative(base, targ)
                    assert.is_nil(relative)
                    assert.not_nil(err)
                end)
            end
        end
    end)
end)
