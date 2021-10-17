local pickers = require "telescope.pickers"
local make_entry = require "telescope.make_entry"
local finders = require "telescope.finders"
local utils = require "telescope.utils"
local conf = require("telescope.config").values

local M = {}

M.find_tests = function(opts)

  -- get the lsp_document_symbols; pass in {symbol="Class"}
  -- to only filter for Kind="Class"
  -- TODO what if there is more than one class? take the outer one
  local params = vim.lsp.util.make_position_params()
  local results_lsp, err = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, opts.timeout or 10000)
  if err then
    vim.api.nvim_err_writeln("Error when finding document symbols: " .. err)
    return
  end

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print "No results from textDocument/documentSymbol"
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result, 0) or {})
  end

  locations = utils.filter_symbols(locations, opts)
  if locations == nil then
    -- error message already printed in `utils.filter_symbols`
    return
  end

  if vim.tbl_isempty(locations) then
    print("no symbols found")
    return
  end

  -- turn the result into a lsp_references request
  -- TODO construct https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentPositionParams
  -- {
    -- textDocument = M.make_text_document_params();
    -- position = make_position_param()
  -- }
  --
  print("locations")
  print(vim.inspect(locations))

  local params = {
    textDocument = {
      uri = vim.uri_from_fname(locations[1].filename)
    },
    position = {
      line = locations[1].lnum - 1,
      character = locations[1].col,
    },
  }
  print("params")
  print(vim.inspect(params))

  -- telescope.builtin.lsp.references
  -- TODO I assume I do not want to include the declaration?
  params.context = { includeDeclaration = true }

  local results_lsp, err = vim.lsp.buf_request_sync(0, "textDocument/references", params, opts.timeout or 10000)
  if err then
    vim.api.nvim_err_writeln("Error when finding references: " .. err)
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.locations_to_items(server_results.result) or {})
    end
  end

  print(vim.inspect(locations))

  -- TODO filter for test files

  -- TODO decide on whether to make a function returning the list of tests
  -- or directly calling telescope on it. probably the first
  -- return locations

  opts.ignore_filename = opts.ignore_filename or true
  pickers.new(opts, {
    prompt_title = "Tests referencing current class",
    finder = finders.new_table {
      results = locations,
      entry_maker = opts.entry_maker or make_entry.gen_from_lsp_symbols(opts),
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.prefilter_sorter {
      tag = "symbol_type",
      sorter = conf.generic_sorter(opts),
    },
  }):find()
end

return M
