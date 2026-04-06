local M = {
  hl_keywords = {
    ["class"] = true,
    ["function"] = true,
    ["namespace"] = true,
    ["method"] = true,
    ["type"] = true,
    ["enum"] = true,
    ["field"] = true,
    ["impl"] = true,
  },

  source = "treesitter", -- treesitter | lsp
  sep = {
    cpp = "::",
    c = "::",
    default = "->",
  },
}

function M.setup(opts)
  M.hl_keywords = opts.hl_keywords or M.hl_keywords
  M.source = opts.source or M.source
  M.sep = vim.tbl_deep_extend("force", M.sep, opts.sep or {})
end

function M:show()
  require(("context.%s"):format(self.source)).context(self, vim.o.ft)
end
return M
