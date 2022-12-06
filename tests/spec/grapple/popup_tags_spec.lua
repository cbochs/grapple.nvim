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
        items = tags,
    },
}

describe("popup_tags", function()
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

    describe("#diff", function()
        it("identifies no changes", function()
            local original_tags = {
                { key = "one", file_path = "relative/path" },
            }
            local modified_tags = {
                { key = "one", file_path = "relative/path" },
            }

            local changes = require("grapple.popup_tags").diff(original_tags, modified_tags)
            assert.equals(0, #changes)
        end)

        it("identifies a deleted tag", function()
            local original_tags = {
                { key = "one", file_path = "relative/path" },
            }
            local modified_tags = {}

            local changes = require("grapple.popup_tags").diff(original_tags, modified_tags)
            assert.equals(1, #changes)
            assert.equals("unset", changes[1].action)
            assert.equals("one", changes[1].change.key)
        end)

        it("identifies renamed tags", function()
            local original_tags = {
                { key = "one", file_path = "relative/path" },
            }
            local modified_tags = {
                { key = "two", file_path = "relative/path" },
            }

            local changes = require("grapple.popup_tags").diff(original_tags, modified_tags)
            assert.equals(1, #changes)

            assert.equals("move", changes[1].action)
            assert.equals("one", changes[1].change.old_key)
            assert.equals("two", changes[1].change.new_key)
        end)

        it("identifies reordered tags", function()
            local original_tags = {
                { key = 1, file_path = "file/one" },
                { key = 2, file_path = "file/two" },
                { key = "one", file_path = "relative/path" },
            }
            local modified_tags = {
                { key = "one", file_path = "relative/path" },
                { key = 2, file_path = "file/two" },
                { key = 1, file_path = "file/one" },
            }

            local changes = require("grapple.popup_tags").diff(original_tags, modified_tags)
            assert.equals(2, #changes)

            assert.equals("move", changes[1].action)
            assert.equals(1, changes[1].change.old_key)
            assert.equals(2, changes[1].change.new_key)

            assert.equals("move", changes[1].action)
            assert.equals(2, changes[2].change.old_key)
            assert.equals(1, changes[2].change.new_key)
        end)
    end)
end)
