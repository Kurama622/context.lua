# context.lua

Show context (namespace, class, function, etc.) in statusline.

![context](https://github.com/user-attachments/assets/478a2a27-c74d-4ff2-b701-4bbf4c8237c6)

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
