# Grapple.nvim

![grapple_select mov](https://user-images.githubusercontent.com/2467016/199631923-e03fad69-b664-4883-83b6-1e9ff6222d81.gif)

## Introduction

Grapple is a plugin that aims to provide immediate navigation to important files by means of [file tags](#tagging) within a [project scope](@tag-scopes).

To get started, [install](#installation) the plugin using your preferred package manager, setup the plugin, and give it a go! You can find the default configuration for the plugin in the section [below](#configuration).

## Features

* **Project scoped** file tagging for immediate navigation
* **Persistent** cursor tracking for tagged files
* **Integration** with [portal.nvim](https://github.com/cbochs/portal.nvim) for additional jump options

## Requirements

* [Neovim >= 0.5](https://github.com/neovim/neovim/releases/tag/v0.5.0)

## Installation

### [packer](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "cbochs/grapple.nvim",
    config = function()
        require("grapple").setup({
            -- Your configuration goes here
            -- Leave empty to use the default configuration
            -- Please see the Configuration section below for more information
        })
    end
}
```

### [Plug](https://github.com/junegunn/vim-plug)

```
Plug "cbochs/grapple.nvim"
```

## Configuration

The following is the default configuration. All configuration options may be overridden during plugin setup.

```lua
require("grapple").setup({
    ---@type "debug" | "info" | "warn" | "error"
    log_level = "warn",

    ---The scope used when creating, selecting, and deleting tags
    ---@type Grapple.Scope
    scope = "global",

    ---The save location for tags
    save_path = vim.fn.stdpath("data") .. "/" .. "grapple.json",

    integrations = {
        ---Support for saving tag state using resession.nvim
        resession = false,
    },
})
```

## Tagging

A `tag` is a persistent tag on a file or buffer. It is a means of indicating a file you want to return to. When a file is tagged, Grapple will save your cursor location so that when you jump back, your cursor is placed right where you left off. In a sense, tags are like file-level marks (`:h mark`).

There are a few types of tag types available, each with a different use-case in mind. The options available are [anonymous](#anonymous-tags) and [named](#named-tags) tags. In addition, tags are [scoped](#tag-scopes) to prevent marks in one project polluting the namespace of another.

### Anonymous Tags

This is the _default_ tag type. Anonymous tags are added to a list, where they may be accessed by index, cycled through, or jumped to using plugins such as [portal.nvim](https://github.com/cbochs/portal.nvim).

Anonymous tags are useful if you're familiar with plugins like [harpoon](https://github.com/ThePrimeagen/harpoon).

**Command** `:GrappleMark [index={index}] [buffer={buffer}]`

```lua
-- Create an anonymous tag
require("grapple").tag()
require("grapple").tag({ index = {index} })

-- Select an anonymous tag
require("grapple").select({ index = {index} })

-- Cycle to the next tag in the list
require("grapple").cycle_backward()
require("grapple").cycle_forward()

-- Delete an anonymous tag
require("grapple").untag() -- untag the current buffer
require("grapple").untag({ index = {index} })
```

### Named Tags

Tags that are given a name are considered to be **namd tags**. These tags will not be cycled through with `cycle_{backward, forward}`, but instead must be explicitly selected.

Named tags are useful if you want one or two keymaps to be used for tagging and selecting. For example, the pairs `<leader>j/J` and `<leader>k/K` to `select/toggle` a file tag. See the [suggested keymaps](#named-tag-keymaps)

**Command** `:GrappleMark name={name} [buffer={buffer}]`

```lua
-- Create a named tag
require("grapple").tag({ name = "{name}" })

-- Select a named tag
require("grapple").select({ name = "{name}" })

-- Delete a named tag
require("grapple").untag({ name = "{name}" })
```

### Tag Scopes

A **scope** is a means of namespacing tags to a specific project. The type of scoping method is set in the configuration during plugin setup. There are currently three options for tag scopes:

```lua
--- @enum Grapple.Scope
M.Scope = {
    --- Tags are ephemeral and are deleted on exit
    NONE = "none",

    --- Use a global namespace for tags
    GLOBAL = "global",

    --- Use the current working directory as the tag namespace
    DIRECTORY = "directory",
}
```

**Used during plugin setup**

```lua
require("grapple").setup({
    scope = "global"
})
```

### Selecting Tags

**Command**: `:GrappleSelect [name={name}] [index={index}] [buffer={buffer}]`

### Deleting Tags

**Commands**:
* `:GrappleUntag [name={name}] [index={index}] [buffer={buffer}]`
* `:GrappleReset [scope]`

```lua
-- Untag the current buffer
require("grapple").untag()

-- Delete a specific tag
require("grapple").untag({ name = "{name}" })
require("grapple").untag({ index = {index} })

-- Delete all tags in the current scope
require("grapple").reset()

-- Delete all tags in a different scope
require("grapple").reset("global")
```

### Suggested Keymaps

#### Anonymous tag keymaps

```lua
vim.keymap.set("n", "<leader>m", require("grapple").toggle, {})
```

#### Named tag keymaps

```lua
vim.keymap.set("n", "<leader>j", function()
    require("grapple").select({ name = "{name}" })
end, {})

vim.keymap.set("n", "<leader>J", function()
    require("grapple").toggle({ name = "{name}" })
end, {})
```

## Integrations

### Lualine

A simple [lualine](https://github.com/nvim-lualine/lualine.nvim) component called `grapple` is provided to show whether a buffer is tagged or not. When a buffer is tagged, the key of the tag will be displayed.

**Tag inactive**

<img width="276" alt="Screen Shot 2022-11-01 at 07 02 09" src="https://user-images.githubusercontent.com/2467016/199238779-955bd8f3-f406-4a61-b027-ac64d049481a.png">

**Tag active**

<img width="276" alt="Screen Shot 2022-11-01 at 07 02 38" src="https://user-images.githubusercontent.com/2467016/199238764-96678f97-8603-45d9-ba2e-9a512ce93727.png">

**Usage**

```lua
require("lualine").setup({
    sections = {
        lualine_b = { "grapple" }
    }
})
```

**Highlight Groups**

```lua
M.groups = {
    lualine_tag_active = "LualineGrappleTagActive",
    lualine_tag_inactive = "LualineGrappleTagInactive",
}
```

### Resession

Backend support is available to use [resession.nvim](https://github.com/stevearc/resession.nvim) for persisting tag state.

**Usage**

```lua
-- Enable resession integration during grapple setup
require("grapple").setup({
    integrations = {
        resession = true
    }
})

-- Enable grapple extension during resession setup
require("resession").setup({
    extensions = {
        grapple = {}
    }
})
```

## Inspiration and Thanks

* tjdevries [vlog.nvim](https://github.com/tjdevries/vlog.nvim)
* ThePrimeagen's [harpoon](https://github.com/ThePrimeagen/harpoon)
* kwarlwang's [bufjump.nvim](https://github.com/kwkarlwang/bufjump.nvim)
