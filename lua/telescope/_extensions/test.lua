local test_builtin = require("telescope._extensions.test_builtin")

return require("telescope").register_extension{
  exports = {
    find_tests = test_builtin.find_tests
  },
}
