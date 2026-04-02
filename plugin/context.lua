vim.api.nvim_create_user_command("ShowContext", function()
  require("context"):show()
end, {})
