local M = {
  hl_keywords = {
    ["class"] = true,
    ["function"] = true,
    ["namespace"] = true,
    ["method"] = true,
    ["type"] = true,
    ["enum"] = true,
    ["field"] = true,
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

local function lsp_context(self, ft)
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

-- signature_match
local default_signature_match = {
  rule = function(signature_type)
    if
      (
        signature_type:find("declarator$")
        or signature_type:find("identifier$")
      ) and signature_type ~= "qualified_identifier"
    then
      return true
    end
  end,
  stop_search = true,
}

local signature_match = {
  sh = {
    rule = function(signature_type)
      if signature_type == "word" then
        return true
      end
    end,
    stop_search = true,
  },
  lua = {
    rule = function(signature_type)
      if
        signature_type:find("identifier$")
        or signature_type:find("_index_expression$")
      then
        return true
      end
    end,
    stop_search = true,
  },
  cpp = {
    rule = default_signature_match.rule,
    stop_search = false,
  },
  c = {
    rule = default_signature_match.rule,
    stop_search = false,
  },
  python = {
    rule = default_signature_match.rule,
    stop_search = true,
  },
}

-- name match
local default_name_match = {
  rule = function(name_type)
    if name_type:find("identifier$") or name_type == "destructor_name" then
      return true
    end
  end,
}

local name_match = {
  cpp = {
    rule = default_name_match.rule,
  },
  c = {
    rule = default_name_match.rule,
  },
}

local function treesitter_context(self, ft)
  local node = vim.treesitter.get_node()
  local tbl = {}

  while node do
    local t = node:type()

    -- declarator|definition|specifier: void print(const char*) { ... }
    if
      t:find("_declaration$")
      or t:find("_definition$")
      or t:find("_specifier$")
    then
      local word = t:match("(%w+)_")
      local hl_type = self.hl_keywords[word] and word or "Conceal"

      --  signature: print(const char*)
      for signature_node in node:iter_children() do
        local signature_type = signature_node:type()
        local sm = signature_match[ft] and signature_match[ft]
          or default_signature_match

        if sm.rule(signature_type) then
          if sm.stop_search then
            goto continue
          end
          hl_type = self.hl_keywords[hl_type] and hl_type
            or signature_type:match("(%w+)_")

          -- name: print
          for name_node in signature_node:iter_children() do
            local name_type = name_node:type()
            local nm = name_match[ft] and name_match[ft] or default_name_match
            if nm.rule(name_type) then
              hl_type = self.hl_keywords[hl_type] and hl_type
                or name_type:match("(%w+)_")
              if self.hl_keywords[hl_type] then
                table.insert(
                  tbl,
                  1,
                  "%#@lsp.type."
                    .. hl_type
                    .. "#"
                    .. vim.treesitter.get_node_text(name_node, 0)
                )
                hl_type = "Conceal"
              end
            end
          end
          ::continue::

          if self.hl_keywords[hl_type] then
            table.insert(
              tbl,
              1,
              "%#@lsp.type."
                .. hl_type
                .. "#"
                .. vim.treesitter.get_node_text(signature_node, 0)
            )
            hl_type = "Conceal"
          end
        end
      end
    end

    node = node:parent()
  end
  if not vim.tbl_isempty(tbl) then
    vim.o.statusline = " %=%##("
      .. table.concat(tbl, "%#Conceal#" .. (self.sep[ft] or self.sep.default))
      .. "%##)%= "
  end
end

function M:show()
  if self.source == "treesitter" then
    treesitter_context(self, vim.o.ft)
  elseif self.source == "lsp" then
    lsp_context(self, vim.o.ft)
  end
end
return M
