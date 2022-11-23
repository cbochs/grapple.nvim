local types = require("grapple.types")
local scope = require("grapple.scope")

local M = {}

function M.create_resolvers()
    ---Scope: "none"
    ---Tags are ephemeral and are deleted on exit
    scope.resolver(function()
        return "__none__"
    end, { key = types.scope.none })

    ---Scope: "global"
    ---Uses a global namespace for tags
    scope.resolver(function()
        return "__global__"
    end, { key = types.scope.global })

    ---Scope: "static"
    ---Uses the working directory set at startup
    scope.resolver(function()
        return vim.fn.getcwd()
    end, { key = types.scope.static })

    ---Scope: "directory"
    ---Uses the current working directory as the tag namespace
    scope.resolver(function()
        return vim.fn.getcwd()
    end, { key = types.scope.directory, invalidates = "DirChanged" })

    ---Scope: "lsp"
    ---Uses the reported "root_dir" from LSP clients as the tag namespace
    scope.fallback(
        scope.resolver(function()
            local clients = vim.lsp.get_active_clients({ bufnr = 0 })
            if #clients > 0 then
                local client = clients[1]
                return client.config.root_dir
            end
        end, { key = types.scope.lsp, invalidates = { "LspAttach", "LspDetach" } }),
        types.scope.static
    )
end

return M
