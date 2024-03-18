local Settings = require("grapple.settings")

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
        it("has the correct scopes default", function()
            local settings = Settings:new()
            -- stylua: ignore
            local names = vim.tbl_map(function(def) return def.name end, settings:scopes())
            assert.same({ "global", "cwd", "git", "git_branch", "lsp" }, names)
        end)

        it("merges default and user-defined scopes", function()
            local settings = Settings:new()
            settings:update({ scopes = { { name = "test" } } })
            -- stylua: ignore
            local names = vim.tbl_map(function(def) return def.name end, settings:scopes())
            assert.same({ "global", "cwd", "git", "git_branch", "lsp", "test" }, names)
        end)

        it("overrides default scope definitions", function()
            local settings = Settings:new()
            settings:update({ default_scopes = { global = { name = "bob" } } })
            -- stylua: ignore
            local names = vim.tbl_map(function(def) return def.name end, settings:scopes())
            assert.same({ "bob", "cwd", "git", "git_branch", "lsp" }, names)
        end)

        it("marks default scopes to be deleted", function()
            local settings = Settings:new()
            settings:update({ default_scopes = { cwd = false } })
            -- stylua: ignore
            local deleted = vim.tbl_filter(function(def) return def.delete end, settings:scopes())
            assert.same({ { name = "cwd", delete = true } }, deleted)
        end)
    end)
end)
