return require("telescope").register_extension({
    exports = {
        tags = require("telescope._extensions.tags"),
    },
})
