local scope = require("grapple.scope")

local resolvers = {}

---Scope: "none"
---Uses a temporary namespace for the project scope. Scope is not persisted
resolvers.none = scope.static("__none__", { persist = false })

---Scope: "global"
---Uses a global namespace for the project scope
resolvers.global = scope.static("__global__")

---Scope: "static"
---Uses the working directory set at startup as the project scope
resolvers.static = scope.resolver(function()
    return vim.fn.getcwd()
end)

---Scope: "directory"
---Uses the current working directory as the project scope
resolvers.directory = scope.resolver(function()
    return vim.fn.getcwd()
end, { cache = "DirChanged" })

---Scope: "git_fallback"
---Fallback: nil
---Uses the current git repository as the project scope
resolvers.git_fallback = scope.root(".git")

---Scope: "git_branch_scope"
---Fallback: nil
---Uses the current git branch as the project scope
resolvers.git_branch_scope = scope.resolver({
    command = "git",
    args = { "symbolic-ref", "--short", "HEAD" },
    cwd = vim.fn.getcwd(),
    on_exit = function(job, return_value)
        if return_value == 0 then
            return job:result()[1]
        else
            return nil
        end
    end,
})

---Scope: "git"
---Fallback: "static"
---Uses the current git repository as the project scope
resolvers.git = scope.fallback({
    "git_fallback",
    "static",
})

---Scope: "git_branch"
---Fallback: "static"
---Uses the current git repository and its branch as the project scope
resolvers.git_branch = scope.fallback({
    scope.suffix("git", "git_branch"),
    "static",
})

---Scope: "lsp_fallback"
---Fallback: nil
---Uses the reported "root_dir" from LSP clients as the project scope
resolvers.lsp_fallback = scope.resolver(function()
    local clients = vim.lsp.get_active_clients({ bufnr = 0 })
    if #clients > 0 then
        local client = clients[1]
        return client.config.root_dir
    end
end, { cache = { "LspAttach", "LspDetach" } })

---Scope: "lsp"
---Fallback: "static"
---Uses the reported "root_dir" from LSP clients as the project scope
resolvers.lsp = scope.fallback({
    "lsp_fallback",
    "static",
})

return resolvers
