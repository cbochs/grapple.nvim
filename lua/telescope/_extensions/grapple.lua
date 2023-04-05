return require("telescope").register_extension {
  exports = {
    hooks = require("telescope._extensions.hooks")
  },
}
