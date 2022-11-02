# Grapple.nvim

## Introduction

Grapple is a plugin that aims to provide immediate navigation to important files within a [project scope](#tag-scopes) and bring you back to exactly where you left off.

To get started, [install](#installation) the plugin using your preferred package manager, setup the plugin, and give it a go! You can find the default configuration for the plugin in the section [below](#configuration).

## Features

* **Project scoped** file tagging for immediate navigation
* **Persistent** cursor tracking for tagged files

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
        ---Integration with portal.nvim. Registers a "tagged" query item
        portal = true,

        -- todo(cbochs): implement
        resession = false,
    },
})
```

## Tagging

A `tag` is a persistent tag on a file or buffer. It is a means of indicating a file you want to return to. When a file is tagged, Grapple will save your cursor location so that when you jump back, your cursor will be placed right where you left off. In a sense, tags are like dynamic marks (`:h mark`).

There are a few types of tag types available, each with a different user in mind. The options available are [anonymous](#anonymous-tags), [named](#named-tags), and [labelled](#labelled-tags) tags. In addition, tags are [scoped](#tag-scopes) to prevent marks in one project polluting the namespace of another.

### Anonymous Tags

This is the _default_ tag type. Anonymous tags are added to a list, where they may be accessed by index, cycled through, or jumped to using plugins such as [portal.nvim](https://github.com/cbochs/portal.nvim).

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

Anonymous tags are usefule if you're used to plugins like [harpoon].

### Named Tags

Named tags allow users to assign a tag to a known key rather than be placed in an unordered list of anonymous tags.

**Command** `:GrappleMark name={name} [buffer={buffer}]`

```lua
-- Create a named tag
require("grapple").tag({ name = "{name}" })

-- Select a named tag
require("grapple").select({ name = "{name}" })

-- Delete a named tag
require("grapple").untag({ name = "{name}" })
```

Named tags are useful if you want to bind one or two keymaps to a specific tag without worrying about anonymous tags messing up the index you originally saved it in.

### Labelled Tags (**not implemented**)

Labelled tags are very similar in nature to named labels. In fact, they are single-character named tags and may be created, selected, or deleted in the same manner as a named tag. The difference being with how they are added. Labelled tags are created in the same manner a vim mark is created: `{motion}{label}` (i.e. `ma` for vim marks). This motion is enabled with the use of either a command or its lua-equivilent:

**Command**: `:GrappleLabel`

```lua
--- Create a labelled mark
require("grapple").label()

--- Select a labelled mark
require("grapple").select{ label = true })
require("grapple").select_label()
```

Labelled tags are useful if you like vim marks, but wish they wouldn't always go back to the exact line you created them.

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
* `:GrappleUnmark`
* `:GrappleReset`

### Suggested Keymaps

_Anonymous tags_

```lua
vim.keymap.set("n", "<leader>m", require("grapple").toggle, {})
```

_Named tags_

```lua
vim.keymap.set("n", "<leader>j", function()
    require("grapple").select({ name = "{name}" })
end, {})

vim.keymap.set("n", "<leader>J", function()
    require("grapple").toggle({ name = "{name}" })
end, {})
```

_Labelled tags_

```lua
vim.keymap.set("n", "m", require("grapple").label, {})
vim.keymap.set("n", "'", require("grapple").select_label, {})
```

## Integrations

### Portal

### Lualine

A simple lualine component called `grapple` is provided to show whether a buffer is tagged or not. When a buffer is tagged, the key of the tag will be displayed.

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
    lualine_tag_active = "PortalLualineTagActive",
    lualine_tag_inactive = "PortalLualineTagInactive",
}
```

## Inspiration and Thanks

* tjdevries [vlog.nvim](https://github.com/tjdevries/vlog.nvim)
* ThePrimeagen's [harpoon](https://github.com/ThePrimeagen/harpoon)
* kwarlwang's [bufjump.nvim](https://github.com/kwkarlwang/bufjump.nvim)
