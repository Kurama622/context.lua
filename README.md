# context.lua

## Installation

```lua
{
  "Kurama622/context.lua",
  cmd = "ShowContext",
  opts = {
    sep = {
      cpp = "::",
      c = "::",
      default = "->",
    },
    source = "treesitter", -- treesitter | lsp
  },
  keys = { { "<C-g>", "<cmd>ShowContext<CR>", desc = "Show Context" } },
}
```
