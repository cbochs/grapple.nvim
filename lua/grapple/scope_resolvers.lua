local scope = require("grapple.scope")

local M = {}

function M.create()
    ---Scope: "none"
    ---Tags are ephemeral and are deleted on exit
    scope.resolver(function()
        return "__none__"
    end, { key = "none" })

    ---Scope: "global"
    ---Uses a global keyspace for tags
    scope.resolver(function()
        return "__global__"
    end, { key = "global" })

    ---Scope: "static"
    ---Uses the working directory set at startup
    scope.resolver(function()
        return vim.fn.getcwd()
    end, { key = "static" })

    ---Scope: "directory"
    ---Uses the current working directory as the tag keyspace
    scope.resolver(function()
        return vim.fn.getcwd()
    end, { key = "directory", cache = "DirChanged" })

    ---Scope: "lsp"
    ---Uses the reported "root_dir" from LSP clients as the tag keyspace
    scope.fallback({
        scope.resolver(function()
            local clients = vim.lsp.get_active_clients({ bufnr = 0 })
            if #clients > 0 then
                local client = clients[1]
                return client.config.root_dir
            end
        end, { cache = { "LspAttach", "LspDetach" } }),
        scope.resolvers.static,
    }, { key = "lsp" })
end

return M
