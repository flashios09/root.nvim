<div align="center">

# root.nvim

A tiny Lua utility module for Neovim to get the **project root path**, heavily inspired([stolen](https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/util/root.lua) 😅) from the only and the one [Folke](https://github.com/folke).

</div>

https://github.com/user-attachments/assets/25c91c81-16fe-45c9-83b6-0d2d41fb854a

Installation
-----------------------------------------------------
Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "flashios09/root.nvim",
  lazy = true,
}
```

Usage
-----------------------------------------------------
```lua
local root = require("root")
print(root.get()) -- `~/.config/nvim/`
```

- With [Snacks explorer](https://github.com/folke/snacks.nvim/blob/main/docs/explorer.md):
```lua
vim.keymap.set("n", "<leader>e", function()
  require("snacks").explorer({ cwd = require("root").get() })
end, { desc = "Explorer Snacks (Root dir)" })
```
- With [Snacks files picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md):
```lua
vim.keymap.set("n", "<leader><space>", function()
  require("snacks").picker.files({ cwd = require("root").get() })
end, { desc = "Find Files (Root Dir)" })
```

- With [NeoTree](https://github.com/nvim-neo-tree/neo-tree.nvim):
```lua
vim.keymap.set("n", "<leader>e", function()
  require("neo-tree.command").execute({ toggle = true, require("root").get() })
end, { desc = "Explorer NeoTree (Root Dir)" })
```

- With [Telescope](https://github.com/nvim-telescope/telescope.nvim):
```lua
vim.keymap.set("n", "<leader><space>", function()
  require("telescope.builtin").find_files({ cwd = require("root").get() })
end, { desc = "Find Files (Root Dir)" })
```

- With [FzfLua](https://github.com/ibhagwan/fzf-lua):
```lua
vim.keymap.set("n", "<leader><space>", function()
  require("fzf-lua").files({ cwd = require("root").get() })
end, { desc = "Find Files (Root Dir)" })
```

- With [barbecue.nvim](https://github.com/flashios09/barbecue.nvim)(see [screenshot](./barbecue-screenshot.png)):
```lua
return {
  "flashios09/barbecue.nvim",
  name = "barbecue",
  version = "*",
  dependencies = {
    "SmiteshP/nvim-navic",
    "flashios09/root.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    require("barbecue").setup({
     -- your custom config here
     -- ..
     -- adding the project name to the barbecue lead section
      lead_custom_section = function()
        local project_name = vim.fn.fnamemodify(require("root").get(), ":t")
        local project_section = {
          { "   " .. project_name .. " ", "BarbecueProject" },
          { "", "BarbecueProjectSeparator" },
          { " ", "BarbecueNormal" },
        }

        return project_section
      end,
    })
  end,
}
```

API
-----------------------------------------------------
#### [root.get(options)](#root-get)
Return the `buffer` root directory.

Based on:
- lsp workspace folders
- lsp root_dir
- root pattern of filename of the current buffer
- root pattern of cwd
##### Example:
```lua
root.get() -- `"/Users/flashios09/.config/nvim/"`
root.get({ buffer = 1 }) -- `"/Users/flashios09/.config/nvim/"`
```

#### [root.git()](#root-git)
Get the git root path if exists.

##### Example:
```lua
root.git() -- `"/Users/flashios09/.config/nvim/"`
```


#### [root.bufpath(buffer)](#root-bufpath)
Get the buffer path.

##### Example:
```lua
root.bufpath(1) -- `"/Users/flashios09/.config/nvim/"`
```


#### [root.norm(path)](#root-norm)
Normalize the buffer path.

- Replace the `~` with the users home dir.
- Normalize the windows path(the directory separator): replace the `\` with `/`.

##### Example:
```lua
root.norm("~/.config/nvim/") -- `"/Users/flashios09/.config/nvim/"`
root.norm("C:\.config\nvim\") -- `"C:/.config/nvim/"
```


#### [root.detect()](#root-detect)
Get all the available root spec(s).

##### Example:
```lua
root.detect()
-- output:
{
  {
    paths = { "/Users/flashios09/.config/nvim" },
    spec = "lsp"
  }, {
    paths = { "/Users/flashios09/.config/nvim" },
    spec = { ".git", "lua" }
  }, {
    paths = { "/Users/flashios09/.config/nvim" },
    spec = "cwd"
  }
}
```
