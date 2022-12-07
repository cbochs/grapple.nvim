local tags = {
    relative = {
        key = "relative",
        file_path = vim.fn.getcwd() .. "/relative/path",
    },
    absolute = {
        key = "absolute",
        file_path = "/absolute/path",
    },
    numbered = {
        key = 1,
        file_path = vim.fn.getcwd() .. "/numbered/tag",
    },
}

local cwd_popup_menu = {
    state = {
        scope = vim.fn.getcwd(),
    },
}

local basic_resolver = require("grapple.scope").static("scope_basic", { persist = false })

local function test_state()
    local state = require("grapple.state")
    local scope = state.ensure_loaded(basic_resolver)
    state.set(scope, { file_path = "/one_file" }, 1)
    state.set(scope, { file_path = "/two_file" }, 2)
    state.set(scope, { file_path = "/yek_file" }, "yek")
end

describe("popup_tags", function()
    before_each(function()
        test_state()
    end)

    after_each(function()
        require("grapple.state").reset()
    end)

    describe("#serialize", function()
        it("serializes a tag with an relative file path", function()
            assert.equals(
                " [relative] relative/path",
                require("grapple.popup_tags").handler.serialize(cwd_popup_menu, tags.relative)
            )
        end)

        it("serializes a tag with an absolute file path", function()
            assert.equals(
                " [absolute] /absolute/path",
                require("grapple.popup_tags").handler.serialize(cwd_popup_menu, tags.absolute)
            )
        end)

        it("serializes a tag with a numbered key", function()
            assert.equals(
                " [1] numbered/tag",
                require("grapple.popup_tags").handler.serialize(cwd_popup_menu, tags.numbered)
            )
        end)
    end)

    describe("#deserialize", function()
        it("parses a line with an absolute path", function()
            local line = require("grapple.popup_tags").handler.serialize(cwd_popup_menu, tags.absolute)
            local parsed_tag = require("grapple.popup_tags").handler.deserialize(cwd_popup_menu, line)
            assert.equals(tags.absolute.key, parsed_tag.key)
            assert.equals(tags.absolute.file_path, parsed_tag.file_path)
        end)

        it("parses a line with a relative path", function()
            local line = require("grapple.popup_tags").handler.serialize(cwd_popup_menu, tags.relative)
            local parsed_tag = require("grapple.popup_tags").handler.deserialize(cwd_popup_menu, line)
            assert.equals(tags.relative.key, parsed_tag.key)
            assert.equals(tags.relative.file_path, parsed_tag.file_path)
        end)

        it("parses a line with a numbered key", function()
            local line = require("grapple.popup_tags").handler.serialize(cwd_popup_menu, tags.numbered)
            local parsed_tag = require("grapple.popup_tags").handler.deserialize(cwd_popup_menu, line)
            assert.equals(tags.numbered.key, parsed_tag.key)
            assert.equals(tags.numbered.file_path, parsed_tag.file_path)
        end)

        it("does not parse an empty line", function()
            assert.is_nil(require("grapple.popup_tags").handler.deserialize(cwd_popup_menu, ""))
        end)
    end)

    describe("#resolve_differences", function()
        it("identifies no changes", function()
            local scope = require("grapple.state").ensure_loaded(basic_resolver)
            local original_tags = require("grapple.state").with_keys(scope)
            local modified_tags = original_tags
            require("grapple.popup_tags").resolve_differences(scope, original_tags, modified_tags)

            local resulting_tags = require("grapple.state").scope(scope)
            assert.equals(3, #vim.tbl_keys(resulting_tags))
            assert.equals("/one_file", resulting_tags[1].file_path)
            assert.equals("/two_file", resulting_tags[2].file_path)
            assert.equals("/yek_file", resulting_tags.yek.file_path)
        end)

        it("identifies a deleted tag", function()
            local scope = require("grapple.state").ensure_loaded(basic_resolver)
            local original_tags = require("grapple.state").with_keys(scope)
            local modified_tags = {
                { file_path = "/two_file", key = 2 },
                { file_path = "/yek_file", key = "yek" },
            }
            require("grapple.popup_tags").resolve_differences(scope, original_tags, modified_tags)

            local resulting_tags = require("grapple.state").scope(scope)
            assert.equals(2, #vim.tbl_keys(resulting_tags))
            assert.equals("/two_file", resulting_tags[1].file_path)
            assert.equals("/yek_file", resulting_tags.yek.file_path)
        end)

        it("identifies renamed tags", function()
            local scope = require("grapple.state").ensure_loaded(basic_resolver)
            local original_tags = require("grapple.state").with_keys(scope)
            local modified_tags = {
                { file_path = "/one_file", key = 1 },
                { file_path = "/two_file", key = 2 },
                { file_path = "/yek_file", key = "yekyek" },
            }
            require("grapple.popup_tags").resolve_differences(scope, original_tags, modified_tags)

            local resulting_tags = require("grapple.state").scope(scope)
            assert.equals(3, #vim.tbl_keys(resulting_tags))
            assert.equals("/one_file", resulting_tags[1].file_path)
            assert.equals("/two_file", resulting_tags[2].file_path)
            assert.equals("/yek_file", resulting_tags.yekyek.file_path)
        end)

        it("identifies reordered tags", function()
            local scope = require("grapple.state").ensure_loaded(basic_resolver)
            local original_tags = require("grapple.state").with_keys(scope)
            local modified_tags = {
                { file_path = "/two_file", key = 2 },
                { file_path = "/yek_file", key = "yekyek" },
                { file_path = "/one_file", key = 1 },
            }
            require("grapple.popup_tags").resolve_differences(scope, original_tags, modified_tags)

            local resulting_tags = require("grapple.state").scope(scope)
            assert.equals(3, #vim.tbl_keys(resulting_tags))
            assert.equals("/two_file", resulting_tags[1].file_path)
            assert.equals("/one_file", resulting_tags[2].file_path)
            assert.equals("/yek_file", resulting_tags.yekyek.file_path)
        end)

        it("identifies reordering and renaming tags", function()
            local scope = require("grapple.state").ensure_loaded(basic_resolver)
            local original_tags = require("grapple.state").with_keys(scope)
            local modified_tags = {
                { file_path = "/yek_file", key = 0 },
                { file_path = "/two_file", key = 2 },
            }
            require("grapple.popup_tags").resolve_differences(scope, original_tags, modified_tags)

            local resulting_tags = require("grapple.state").scope(scope)
            assert.equals(2, #vim.tbl_keys(resulting_tags))
            assert.equals("/yek_file", resulting_tags[1].file_path)
            assert.equals("/two_file", resulting_tags[2].file_path)
        end)

        it("does not add new tags", function()
            local scope = require("grapple.state").ensure_loaded(basic_resolver)
            local original_tags = require("grapple.state").with_keys(scope)
            local modified_tags = {
                { file_path = "/one_file", key = 1 },
                { file_path = "/two_file", key = 2 },
                { file_path = "/yek_file", key = "yek" },
                { file_path = "/thr_file", key = 2 },
            }
            require("grapple.popup_tags").resolve_differences(scope, original_tags, modified_tags)

            local resulting_tags = require("grapple.state").scope(scope)
            assert.equals(3, #vim.tbl_keys(resulting_tags))
            assert.equals("/one_file", resulting_tags[1].file_path)
            assert.equals("/two_file", resulting_tags[2].file_path)
            assert.equals("/yek_file", resulting_tags.yek.file_path)
        end)
    end)
end)
