local test_builtin = require("telescope._extensions.test_builtin")

return require("telescope").register_extension{
  exports = {
    list = test_builtin.list
  },
}
