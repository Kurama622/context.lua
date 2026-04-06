local lsp = {}
local function binary_search(tbl, line)
  local left = 1
  local right = #tbl
  local mid = 0

  while true do
    mid = bit.rshift(left + right, 1)
    if not tbl[mid] then
      return
    end

    local range = tbl[mid].range or tbl[mid].location.range
    if not range then
      return
    end

    if line >= range.start.line and line <= range["end"].line then
      return mid
    elseif line < range.start.line then
      right = mid - 1
    else
      left = mid + 1
    end
    if left > right then
      return
    end
  end
end

function lsp.context(self, ft)
  local params = { textDocument = vim.lsp.util.make_text_document_params() }

  vim.lsp.buf_request(
    0,
    "textDocument/documentSymbol",
    params,
    function(err, result, ctx)
      if err or not result or not vim.api.nvim_buf_is_loaded(ctx.bufnr) then
        return
      end

      local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
      local mid = binary_search(result, lnum)

      if not mid then
        return
      end

      local function filter(tbl)
        local filtered = {}
        if tbl.children == nil or vim.tbl_isempty(tbl.children) then
          return {}
        end
        for _, s in ipairs(tbl.children) do
          if
            (s.range["start"].line <= lnum and s.range["end"].line >= lnum)
            and (
              s.kind == vim.lsp.protocol.SymbolKind.Function
              or s.kind == vim.lsp.protocol.SymbolKind.Method
              or s.kind == vim.lsp.protocol.SymbolKind.Class
              or s.kind == vim.lsp.protocol.SymbolKind.Namespace
              or s.kind == vim.lsp.protocol.SymbolKind.Constructor
              or s.kind == vim.lsp.protocol.SymbolKind.Object
            )
          then
            table.insert(filtered, s)
          end

          if s.children and not vim.tbl_isempty(s.children) then
            s.children = filter(s)
          end
        end
        return filtered
      end

      result[mid].children = filter(result[mid])

      local symbols = vim.tbl_filter(
        function(t)
          return t.kind == "Function"
            or t.kind == "Method"
            or t.kind == "Class"
            or t.kind == "Namespace"
            or t.kind == "Constructor"
            or t.kind == "Object"
        end,
        vim.lsp.util.symbols_to_items(
          { result[mid] },
          0,
          vim.lsp.get_clients({ bufnr = 0 })[1].offset_encoding
        )
      )

      local symbol_name = vim.tbl_map(function(t)
        local kind = t.text:match("%[(%w+)%]%s*")
        return t.text:gsub(
          "%[" .. kind .. "%]%s*",
          "%%#@lsp.type." .. kind:lower() .. "#"
        )
      end, symbols)
      if not vim.tbl_isempty(symbol_name) then
        vim.o.statusline = (" %%=(%s%%##)%%= "):format(
          table.concat(
            symbol_name,
            "%#Conceal#" .. (self.sep[ft] or self.sep.default)
          )
        )
      end
    end
  )
end
return lsp
