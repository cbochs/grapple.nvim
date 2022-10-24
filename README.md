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

## Jumping

## Usage

### `:GrappleMark`
### `:GrappleUnmark`
### `:GrappleToggle`
### `:GrappleJumpForward`
### `:GrappleJumpBackward`

## Special Thanks

Thanks to tjdevries for easy logging with [vlog.nvim](https://github.com/tjdevries/vlog.nvim)

## Inspiration

* ThePrimeagen's [harpoon](https://github.com/ThePrimeagen/harpoon)
* kwarlwang's [bufjump.nvim](https://github.com/kwkarlwang/bufjump.nvim)
