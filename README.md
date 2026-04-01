# context.lua

## Installation

```lua
{
  "Kurama622/context.lua",
  opts = {
    sep = {
      cpp = "::",
      c = "::",
      default = "->",
    },
    source = "treesitter", -- treesitter | lsp
  },
  keys = {
    {
      "<C-g>",
      function()
        require("context"):show()
      end,
      desc = "Show Context"
    },
  },
}
```
