local treesitter = {}
local default_specifier_match = {
  rule = function(specifier)
    if
      specifier:find("_declaration$")
      or specifier:find("_definition$")
      or specifier:find("_specifier$")
    then
      return true
    end
  end,
}
local specifier_match = {
  cpp = { rule = default_specifier_match.rule },
  c = { rule = default_specifier_match.rule },
  python = { rule = default_specifier_match.rule },
  rust = {
    rule = function(specifier)
      if specifier:find("_item$") then
        return true
      end
    end,
  },
}

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
  rust = {
    rule = function(signature_type)
      if
        signature_type:find("identifier$")
        or signature_type == "generic_type"
      then
        return true
      end
    end,
    stop_search = false,
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

function treesitter.context(self, ft)
  local node = vim.treesitter.get_node()
  local tbl = {}

  while node do
    local specifier_node = node:type()

    -- specifier(declarator|definition): void print(const char*) { ... }
    local spfm = specifier_match[ft] and specifier_match[ft]
      or default_specifier_match
    if spfm.rule(specifier_node) then
      local word = specifier_node:match("(%w+)_")
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
                break
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
            break
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
return treesitter
