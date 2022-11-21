local M = {}

---@enum Grapple.Direction
M.direction = {
    backward = "backward",
    forward = "forward",
}

---@enum Grapple.ScopeType
M.scope = {
    ---Tags are ephemeral and are deleted on exit
    none = "none",

    ---Use a global namespace for tags
    global = "global",

    ---Use the working directory set at startup
    static = "static",

    ---Use the current working directory as the tag namespace
    directory = "directory",

    ---Use the closest working git repository as the tag namespace
    git = "git",

    ---Use the reported "root_dir" from LSP clients as the tag namespace
    lsp = "lsp",
}

return M
