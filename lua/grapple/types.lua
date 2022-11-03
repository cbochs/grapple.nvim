local M = {}

---@enum Grapple.Direction
M.Direction = {
    BACKWARD = 0,
    FORWARD = 1,
}

---@enum Grapple.Scope
M.Scope = {
    ---Tags are ephemeral and are deleted on exit
    NONE = "none",

    ---Use a global namespace for tags
    GLOBAL = "global",

    ---Use the current working directory as the tag namespace
    DIRECTORY = "directory",

    ---Use the reported "root_dir" from LSP clients as the tag namespace
    LSP = "lsp",
}

return M
