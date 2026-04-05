# context.lua

Show context (namespace, class, function, etc.) in statusline.

![context](https://github.com/user-attachments/assets/b57c96e3-9f24-44ce-9a63-845280c4d6f4)

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
