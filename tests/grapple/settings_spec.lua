local Settings = require("grapple.settings")
local Util = require("grapple.util")

describe("Settings", function()
    describe("Defaults", function()
        it("has the correct style defaults", function()
            local settings = Settings:new()
            assert.same(true, settings.icons)
            assert.same(true, settings.status)
            assert.same("end", settings.name_pos)
            assert.same("relative", settings.style)
        end)

        it("has the correct scope default", function()
            assert.same("git", Settings:new().scope)
        end)

        it("has the correct command default", function()
            assert.same(vim.cmd.edit, Settings:new().command)
        end)
    end)

    describe(".quick_select", function()
        it("has the correct quick_select default", function()
            assert.same({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, Settings:new():quick_select())
        end)

        it("can be set to an empty string to disable quick select", function()
            local settings = Settings:new()
            settings:update({ quick_select = "" })
            assert.same({}, settings:quick_select())
        end)

        it("can be set to false to disable quick select", function()
            local settings = Settings:new()
            settings:update({ quick_select = false })
            assert.same({}, settings:quick_select())
        end)
    end)

    describe(".scopes", function()
        it("has the correct scope defaults in priority order", function()
            local settings = Settings:new()
            local names = vim.tbl_map(Util.pick("name"), settings:scopes())
            assert.same({ "cwd", "global", "static", "git", "git_branch", "lsp" }, names)
        end)

        it("merges default and user-defined scopes", function()
            local settings = Settings:new()
            settings:update({ scopes = { test = {} } })
            local names = vim.tbl_map(Util.pick("name"), settings:scopes())
            assert.same({ "cwd", "global", "static", "test", "git", "git_branch", "lsp" }, names)
        end)

        it("overrides default scope definitions", function()
            local settings = Settings:new()
            settings:update({ default_scopes = { global = { name = "bob" } } })
            local names = vim.tbl_map(Util.pick("name"), settings:scopes())
            assert.same({ "bob", "cwd", "static", "git", "git_branch", "lsp" }, names)
        end)

        it("marks default scopes to be deleted", function()
            local settings = Settings:new()
            settings:update({ default_scopes = { cwd = false } })
            -- stylua: ignore
            local deleted = vim.tbl_filter(function(def) return def.delete end, settings:scopes())
            assert.same(1, #deleted)
            assert.same("cwd", deleted[1].name)
            assert.same(true, deleted[1].delete)
        end)

        it("hides all scopes except those with 'shown'", function()
            local settings = Settings:new()
            settings:update({ default_scopes = { git = { shown = true } } })

            -- stylua: ignore
            local hidden = vim.tbl_map(
                Util.pick("name"),
                vim.tbl_filter(function(def) return def.hidden == true end, settings:scopes())
            )
            assert.same({ "cwd", "global", "static", "git_branch", "lsp" }, hidden)

            -- stylua: ignore
            local not_hidden = vim.tbl_map(
                Util.pick("name"),
                vim.tbl_filter(function(def) return def.hidden == false end, settings:scopes())
            )
            assert.same({ "git" }, not_hidden)
        end)
    end)
end)
