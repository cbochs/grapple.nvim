local scope = require("grapple.scope")

local resolvers = {}

---Scope: "none"
---Tags are ephemeral and are deleted on exit
resolvers.none = scope.static("__none__")

---Scope: "global"
---Uses a global keyspace for tags
resolvers.global = scope.static("__global__")

---Scope: "static"
---Uses the working directory set at startup
resolvers.static = scope.resolver(function()
    return vim.fn.getcwd()
end)

---Scope: "directory"
---Uses the current working directory as the tag keyspace
resolvers.directory = scope.resolver(function()
    return vim.fn.getcwd()
end, { cache = "DirChanged" })

---Scope: "git_fallback"
---Fallback: nil
---Uses the current git repository as the tag namespace.
resolvers.git_fallback = scope.root(".git")

---Scope: "git"
---Fallback: "static"
---Uses the current git repository as the tag namespace.
resolvers.git = scope.fallback({
    "git_fallback",
    "static",
})

---Scope: "lsp_fallback"
---Fallback: nil
---Uses the reported "root_dir" from LSP clients as the tag keyspace
resolvers.lsp_fallback = scope.resolver(function()
    local clients = vim.lsp.get_active_clients({ bufnr = 0 })
    if #clients > 0 then
        local client = clients[1]
        return client.config.root_dir
    end
end, { cache = { "LspAttach", "LspDetach" } })

---Scope: "lsp"
---Fallback: "static"
---Uses the reported "root_dir" from LSP clients as the tag keyspace
resolvers.lsp = scope.fallback({
    "lsp_fallback",
    "static",
})

return resolvers
