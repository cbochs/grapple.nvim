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
    log_level = "warn",
    project_root = vim.fn.getcwd(),
    state_path   = vim.fn.stdpath("data") .. "/" .. "grapple.json",
}
```

## Marking

A **marked** file is an important file you want to return to with as little keystrokes as possible. Files may be marked, unmarked, and toggled. Marks may be created with a `name` (and optionally `buffer`) to be referenced later.

https://user-images.githubusercontent.com/2467016/197600951-1f5ab942-e8b5-43b7-b53b-c97b939d3f78.mov

```lua
vim.keymap.set( "n", "<leader>k", function()
    require("grapple").select({ name = "Kepler" })
end, { desc = "Select a named mark" })

vim.keymap.set("n", "<leader>K", function()
    require("grapple").toggle({ name = "Kepler" })
end, { desc = "Toggle a named mark" })
```

## Jumping

A **marked** file can be quickly navigated to from `:h jumplist`.

https://user-images.githubusercontent.com/2467016/197601258-4a5b4c75-657d-4547-9f36-3120ed2cfeed.mov

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

Mark a file. Optionally accepts a `buffer` number, and either a mark `name` or numbered mark `index`. If nothing is provided, `buffer` will default to `0` (current buffer) and the mark will be inserted in the first available index. Marks with identical file paths with be replaced.

```
:GrappleMark [buffer={buffer}] [name={name}] [index={index}]
```

### `:GrappleUnmark`

Unmark a file. Optionally accepts a `buffer` number, mark `name`, or numbered mark `index`. If nothing is provided, `buffer` will default to `0` (current buffer).

```
:GrappleUnmark [buffer={buffer}] [name={name}] [index={index}]
```

### `:GrappleToggle`

Toggle a mark on a file. Optionally accepts a `buffer` number, and either a mark `name` or numbered mark `index`. If nothing is provided, `buffer` will default to `0` (current buffer). Creation behaviour is the same as `:GrappleMark`.

```
:GrappleToggle [buffer={buffer}] [name={name}] [index={index}]
```

### `:GrappleSelect`

Select and open a marked file. Must provide either a `buffer` number, mark `name`, or numbered mark `index`.

```
:GrappleSelect [buffer={buffer}] [name={name}] [index={index}]
```

### `:GrappleReset`

Reset marks for the current project.

### `:GrappleResetAll`

Reset marks for all projects.

### `:GrappleJumpForward`

Jump forward in the jumplist to a marked file, if possible.

### `:GrappleJumpBackward`

Jump backward in the jumplist to a marked file, if possible.

## Inspiration and Thanks

* tjdevries [vlog.nvim](https://github.com/tjdevries/vlog.nvim)
* ThePrimeagen's [harpoon](https://github.com/ThePrimeagen/harpoon)
* kwarlwang's [bufjump.nvim](https://github.com/kwkarlwang/bufjump.nvim)
