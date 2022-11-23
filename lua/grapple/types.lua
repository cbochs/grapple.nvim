local M = {}

---@enum Grapple.Direction
M.direction = {
    backward = "backward",
    forward = "forward",
}

---@enum table<string, Grapple.ScopeKey>
M.scope = {
    none = "none",
    global = "global",
    static = "static",
    directory = "directory",
    lsp = "lsp",
}

return M
