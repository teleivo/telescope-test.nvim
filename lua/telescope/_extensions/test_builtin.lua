local pickers = require "telescope.pickers"
local make_entry = require "telescope.make_entry"
local finders = require "telescope.finders"
local utils = require "telescope.utils"
local conf = require("telescope.config").values

local M = {}

local function list_tests(opts)
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
  -- construct https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocumentPositionParams
  local params = {
    textDocument = {
      uri = vim.uri_from_fname(locations[1].filename)
    },
    position = {
      line = locations[1].lnum - 1,
      character = locations[1].col,
    },
  }

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

  -- filter locations for tests
  -- TODO this might differ by language
  -- would it make sense/be feasible to look for an import/annotation
  -- to confirm its a test as opposed to just looking for a pattern in the
  -- filename?
  --
  -- TODO I create a set so test files only occur once
  -- how do I choose which of the references to take?
  -- or do I simply override their lnum and col to 0?
   local tests = {}
   for _, l in ipairs(locations) do
     if string.find(l.filename, "[tT]est") then
       tests[l.filename] = l
     end
   end

   -- turn it into a location list for telescope
  -- into files
   local test_locations = {}
   for _, tl in pairs(tests) do
     test_locations[#test_locations+1] = {
      value = tl.filename,
    }
   end

   -- TODO why is the DateTimeUnitTest not included?
  return test_locations
end

M.list_tests = list_tests

M.list = function(opts)
  opts = opts or { symbols = "Class" }
  local locations = list_tests(opts)

  -- TODO do not show the message. does that mean I don't want the previewer? 
  pickers.new(opts, {
    prompt_title = "LSP Test References",
    finder = finders.new_table {
      results = locations,
      entry_maker = opts.entry_maker or make_entry.gen_from_file(opts),
    },
    previewer = conf.file_previewer(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

return M
