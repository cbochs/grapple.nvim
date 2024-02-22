local Helpers = require("tests.helpers")
local Util = require("grapple.util")

local function test_path(desc, method, expected, ...)
    local args = { ... }
    it(desc, function()
        assert.same(expected, method(unpack(args)))
    end)
end

describe("util", function()
    describe(".absolute", function()
        before_each(function()
            Helpers.fs_layout({
                root = {
                    start = {
                        file = "",
                        dir = {
                            file = "",
                            dir = {},
                        },
                    },
                },
            })
            Helpers.fs_cd("root/start")
        end)

        after_each(function()
            Helpers.fs_rm("root", "rf")
        end)

        local function test_abs(expected, path)
            it(string.format('parses "%s"', path), function()
                assert.are.same(expected, Util.absolute(path))
            end)
        end

        local function test_abs_fail(path)
            it(string.format('does not parse "%s"', path), function()
                local abs_path, err = Util.absolute(path)
                assert.are.same("", abs_path)
                assert.not_nil(err)
            end)
        end

        -- Single dot operative, once
        test_abs(Helpers.fs_path("root/start/dir/"), "dir")
        test_abs(Helpers.fs_path("root/start/file"), "file")

        test_abs(Helpers.fs_path("root/start/"), ".")
        test_abs(Helpers.fs_path("root/start/"), "./")
        test_abs(Helpers.fs_path("root/start/dir/"), "./dir")
        test_abs(Helpers.fs_path("root/start/file"), "./file")

        test_abs(Helpers.fs_path("root/start/dir/dir/"), "dir/./dir")
        test_abs(Helpers.fs_path("root/start/dir/file"), "dir/./file")

        test_abs(Helpers.fs_path("root/start/dir/"), "dir/.")
        test_abs(Helpers.fs_path("root/start/file"), "file/.")

        test_abs(Helpers.fs_path("root/start/dir/"), "dir/./")
        test_abs(Helpers.fs_path("root/start/file"), "file/./")

        -- Single dot operative, consecutive
        test_abs(Helpers.fs_path("root/start/dir/"), "././dir")
        test_abs(Helpers.fs_path("root/start/file"), "././file")

        test_abs(Helpers.fs_path("root/start/dir/dir/"), "dir/././dir")
        test_abs(Helpers.fs_path("root/start/dir/file"), "dir/././file")

        test_abs(Helpers.fs_path("root/start/dir/"), "dir/./.")
        test_abs(Helpers.fs_path("root/start/file"), "file/./.")

        test_abs(Helpers.fs_path("root/start/dir/"), "dir/././")
        test_abs(Helpers.fs_path("root/start/file"), "file/././")

        -- Double dot operative, once
        test_abs(Helpers.fs_path("root/"), "..")
        test_abs(Helpers.fs_path("root/"), "../")
        test_abs(Helpers.fs_path("root/start/dir/"), "../start/dir")
        test_abs(Helpers.fs_path("root/start/file"), "../start/file")

        test_abs(Helpers.fs_path("root/start/dir/"), "dir/../dir")
        test_abs(Helpers.fs_path("root/start/file"), "dir/../file")

        test_abs(Helpers.fs_path("root/start/"), "dir/..")
        test_abs(Helpers.fs_path("root/start/"), "file/..")

        test_abs(Helpers.fs_path("root/start/"), "dir/../")
        test_abs(Helpers.fs_path("root/start/"), "file/../")

        -- Double dot operative, consecutive
        test_abs(Helpers.fs_path(), "../..")
        test_abs(Helpers.fs_path(), "../../")
        test_abs(Helpers.fs_path("root/start/dir/"), "../../root/start/dir")
        test_abs(Helpers.fs_path("root/start/file"), "../../root/start/file")

        test_abs(Helpers.fs_path("root/start/dir/"), "dir/../../start/dir")
        test_abs(Helpers.fs_path("root/start/file"), "dir/../../start/file")

        test_abs(Helpers.fs_path("root/"), "dir/../..")
        test_abs(Helpers.fs_path("root/"), "file/../..")

        -- Combined operatives
        test_abs(Helpers.fs_path("root/start/"), "dir/./file/../../dir/../")

        -- Invalid paths
        test_abs_fail("./does_not_exist")
        test_abs_fail("...")
        test_abs_fail("")
    end)

    describe(".relative", function()
        local function assert_rel(path, root, expected)
            test_path(string.format("parses %s with %s", path, root), Util.relative, path, root, expected)
        end
    end)
end)
