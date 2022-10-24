# Grapple.nvim

**grapple.nvim** is a lua plugin for Neovim which helps you keep important files as close as possible.

## Features

* Project-local **file marking** and **persistent** cursor tracking
* Jumping forward and backward between marked files

## Installation

### [packer](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "cbochs/grapple.nvim",
    config = function()
        require("grapple").setup({
            -- Your configuration goes here
            -- Leave empty to use the default configuration
            -- Refer to the configuration section for more details
        })
    end
}
```

## Configuration

```lua
local default = {
    log = {
        level = "error",
        use_console = false,
    },
    project_root = vim.fn.getcwd(),
    state_path   = vim.fn.stdpath("data") .. "/" .. "grapple.json",
}
```

## Marking

A **marked** file is an important file you want to return to with as little keystrokes as possible. Files may be marked, unmarked, and toggled. Marks may be created with a `name` (and optionally `buffer`) to be referenced later.

```lua
vim.keymap.set( "n", "<leader>j", function()
    require("grapple").select({ name = "Jacob" })
end, { desc = "Select a named mark" })

vim.keymap.set("n", "<leader>J", function()
    require("grapple").toggle({ name = "Jacob" })
end, { desc = "Toggle a named mark" })
```

## Jumping

A **marked** file can be quickly navigated to from `:h jumplist`.

```lua
vim.keymap.set( "n", "<leader>i", function()
    require("grapple").jump_forward()
end, { desc = "Jump forwards to marked file" })

vim.keymap.set( "n", "<leader>o", function()
    require("grapple").jump_forward()
end, { desc = "Jump backwards to a marked file" })
```

## Usage

### `:GrappleMark`

Mark a file. Optionally accepts a `buffer` number and a mark `name`. If nothing is provided, `buffer` will default to `0` (current buffer).

```
:GrappleMark [buffer={buffer}] [name={name}]
```

### `:GrappleUnmark`

Unmark a file. Optionally accepts a `buffer` number and a mark `name`. If nothing is provided, `buffer` will default to `0` (current buffer)

```
:GrappleUnmark [buffer={buffer}] [name={name}]
```

### `:GrappleToggle`

Toggle a mark on a file. Optionally accepts a `buffer` number and a mark `name`. If nothing is provided, `buffer` will default to `0` (current buffer)

```
:GrappleToggle [buffer={buffer}] [name={name}]
```

### `:GrappleSelect`

Select and open a marked file. Must provide either a `buffer` number or a mark `name`.

```
:GrappleSelect [buffer={buffer}] [name={name}]
```

### `:GrappleReset`

Reset marks marks for the current project.

### `:GrappleResetAll`

Reset marks marks for the current project.

### `:GrappleJumpForward`

Jump forward in the jumplist to a marked file, if possible.

### `:GrappleJumpBackward`

Jump backward in the jumplist to a marked file, if possible.

## Special Thanks

Thanks to tjdevries for easy logging with [vlog.nvim](https://github.com/tjdevries/vlog.nvim)

## Inspiration

* ThePrimeagen's [harpoon](https://github.com/ThePrimeagen/harpoon)
* kwarlwang's [bufjump.nvim](https://github.com/kwkarlwang/bufjump.nvim)
