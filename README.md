# Grapple.nvim

![grapple_showcase_tagging](https://user-images.githubusercontent.com/2467016/199631923-e03fad69-b664-4883-83b6-1e9ff6222d81.gif)

_Theme: [catppuccin](https://github.com/catppuccin/nvim)_

## Introduction

Grapple is a plugin that aims to provide immediate navigation to important files (and its last known cursor location) by means of persistent [file tags](#file-tags) within a [project scope](#tag-scopes). Tagged files can be bound to a [keymap](#suggested-keymaps) or selected from within an editable [popup menu](#popup-menu).

To get started, [install](#installation) the plugin using your preferred package manager, setup the plugin, and give it a go! Default configuration for the plugin can be found in the [configuration](#configuration) section below. The API provided by Grapple can be found in the [usage](#usage) section below.

## Features

* **Project scoped** file tagging for immediate navigation
* **Persistent** cursor tracking for tagged files
* **Popup** menu to manage tags and scopes as regular text
* **Integration** with [portal.nvim](https://github.com/cbochs/portal.nvim) for additional jump options

## Requirements

* [Neovim >= 0.5](https://github.com/neovim/neovim/releases/tag/v0.5.0)
* Neovim >= 0.9 - OPTIONAL for popup title

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

    ---Window options used for the popup menu
    popup_options = {
        relative = "editor",
        width = 60,
        height = 12,
        style = "minimal",
        focusable = false,
        border = "single",
    },

    integrations = {
        ---Support for saving tag state using resession.nvim
        resession = false,
    },
})
```

## File Tags

A **tag** is a persistent tag on a file or buffer. It is a means of indicating a file you want to return to. When a file is tagged, Grapple will save your cursor location so that when you jump back, your cursor is placed right where you left off. In a sense, tags are like file-level marks (`:h mark`).

There are a couple types of tag types available, each with a different use-case in mind. The options available are [anonymous](#anonymous-tags) and [named](#named-tags) tags. In addition, tags are [scoped](#tag-scopes) to prevent tags in one project polluting the namespace of another. For command and API information, please see the [usage](#usage) below.

### Anonymous Tags

This is the _default_ tag type. Anonymous tags are added to a list, where they may be accessed by index, cycled through, or jumped to using plugins such as [portal.nvim](https://github.com/cbochs/portal.nvim).

Anonymous tags are similar to those found in plugins like [harpoon](https://github.com/ThePrimeagen/harpoon).

### Named Tags

Tags that are given a name are considered to be **named tags**. These tags will not be cycled through with `cycle_{backward, forward}`, but instead must be explicitly selected.

Named tags are useful if you want one or two keymaps to be used for tagging and selecting. For example, the pairs `<leader>j/J` and `<leader>k/K` to `select/toggle` a file tag. See the [suggested keymaps](#named-tag-keymaps)

### Tag Scopes

A **scope** is a means of namespacing tags to a specific project. During runtime, scopes are resolved into a file path, which - in turn - are used as the "root" location for a set of tags.

Some scopes may be falliable (i.e. `"lsp"`). Whenever a scope is unable to resolve to a file path, the scope will fallback to `"directory"`.

For now, there are five different scope options:

* `"none"`: Tags are ephemeral and deleted on exit
* `"global"`: Tags are scoped to a global namespace
* `"directory"`: Tags are scoped to the current working directory
* `"lsp"`: Tags are scoped using the `root_dir` of the current buffer's attached LSP server
* [`Grapple.ScopeResolver`](#grapplescoperesolver): Tags are scoped using a provided resolving function

**Used during plugin setup**

```lua
-- Configure using a builtin type
require("grapple").setup({
    scope = "directory"
})

-- Configure using a custom scope resolver
require("grapple").setup({
    scope = function()
        return vim.fn.getcwd()
    end
})
```

## Popup Menu

A popup menu is available to enable easy management of tags and scopes. The opened buffer (filetype: `grapple`) can be modified like a regular buffer; meaning items can be selected, modified, reordered, or deleted with well-known vim motions. Currently, there are two available popup menus: one for [tags](#tag-popup-menu) and another for [scopes](#scope-popup-menu).

### Tag Popup Menu

The **tags popup menu** opens a floating window containing all the tags within a specified scope. The floating window can be exited with either `q`, `<esc>`, or any keybinding that is bound to `<esc>`. Several actions are available within the tags popup menu:
* **Selection**: a tag can be selected by moving to its corresponding line and pressing enter (`<cr>`)
* **Deletion**: a tag (or tags) can be removed by deleting them from the popup menu (i.e. NORMAL `dd` and VISUAL `d`)
* **Reordering**: an [anonymous tag](#anonymous-tags) (or tags) can be reordered by moving them up or down within the popup menu. Ordering is determined by the tags position within the popup menu: top (first index) to bottom (last index)
* **Renaming**: a [named tag](#named-tags) can be renamed by editing its key value between the `[` square brackets `]`


**Command**: `:GrapplePopup tags`

**API**: `require("grapple").popup_tags(scope)`

**Scope**: [`Grapple.Scope`](#grapplescope)

**Examples**

```lua
-- Open the tags popup menu in the current scope
require("grapple").popup_tags()

-- Open the tags popup menu in a different scope
require("grapple").popup_tags("global")
```

### Scope Popup Menu

The **scopes popup menu** opens a floating window containing all the scope paths that have been created. A scope (or scopes) can be deleted with typical vim edits (i.e. NORMAL `dd` and VISUAL `d`). The floating window can be exited with either `q` or any keybinding that is bound to `<esc>`. The total number of tags within a scope will be displayed to the left of the scope path.

**Command**: `:GrapplePopup scopes`

**API**: `require("grapple.popup_scopes()`

**Examples**

```lua
-- Open the scopes popup menu
require("grapple").popup_scopes()
```

## Usage

### Tagging a file

Create a scoped tag on a file or buffer with an (optional) tag key.

**Note**: only one tag can be created _per scope per file_. If a tag already exists for the given file or buffer, it will be overridden with the new tag.

**Command**: `:GrappleTag [key={index} or key={name}] [buffer={buffer}] [file_path={file_path}]`

**API**: `require("grapple").tag(opts)`

**Options**: [`Grapple.Options`](#grappleoptions)

* buffer: `integer` (optional, default: `0`)
* file_path: `string` (optional, overrides `buffer`)
* key: [`Grapple.TagKey`](#grappletagkey) (optional, default appended)

**Examples**

```lua
-- Tag the current buffer
require("grapple").tag()

-- Tag a file using its file path
require("grapple").tag({ file_path = "{file_path}" })

-- Tag the curent buffer using a specified key
require("grapple").tag({ key = 1 })
require("grapple").tag({ key = "{name}" })
```

### Toggling a tag on a file

Conditionally tag or untag a file or buffer based on whether the tag already exists or not.

**Command**: `:GrappleToggle [key={index} or key={name}] [buffer={buffer}] [file_path={file_path}]`

**API**: `require("grapple").toggle(opts)`

**Options**: [`Grapple.Options`](#grappleoptions)

* buffer: `integer` (optional, default: `0`)
* file_path: `string` (optional, overrides `buffer`)
* key: [`Grapple.TagKey`](#grappletagkey) (optional, default: inherited from [tag](#taggg-a-file) and [untag](#removing-a-tag-on-a-file))

```lua
-- Toggle a tag on the current buffer
require("grapple").toggle()
```

### Removing a tag on a file

Remove a scoped tag on a file or buffer.

**Command**: `:GrappleUntag [key={name} or key={index}] [buffer={buffer}] [file_path={file_path}]`

**API**: `require("grapple").untag(opts)`

**Options**: [`Grapple.Options`](#grappleoptions) (one of)

* buffer: `integer` (default: `0`)
* file_path: `string` (overrides `buffer`)
* key: [`Grapple.TagKey`](#grappletagkey) (overrides `buffer` and `file_path`)

**Examples**

```lua
-- Untag the current buffer
require("grapple").untag()

-- Untag a file using its file path
require("grapple").untag({ file_path = "{file_path}" })

-- Untag a file using its tag key
require("grapple").untag({ key = 1 })
require("grapple").untag({ key = "{name}" })
```

### Selecting a tagged file

Open a tagged file or buffer in the current window.

**Command**: `:GrappleSelect [key={index} or key={name}]`

**API**: `require("grapple").select(opts)`

**Options**: [`Grapple.Options`](#grappleoptions) (one of)

* buffer: `integer`
* file_path: `string`
* key: [`Grapple.TagKey`](#grappletagkey) (preferred)

**Examples**

```lua
-- Select an anonymous (numbered) tag
require("grapple").select({ key = 1 })

-- Select a named tag
require("grapple").select({ key = "{name}" })
```

### Cycling through tagged files

Select the next available tagged file from the scoped tag list.

**Note**: only [anonymous tags](#anonymous-tags) are cycled through, not [named tags](#named-tags).

**Command**: N/A

**API**:
* `require("grapple").cycle_backward()`
* `require("grapple").cycle_forward()`

```lua
-- Cycle to the previous tagged file
require("grapple").cycle_backward()

-- Cycle to the next tagged file
require("grapple").cycle_forward()
```

### Resetting a tag scope

Clear all tags for a tag scope.

**Command**: `:GrappleReset [scope]`

**API**: `require("grapple").reset(scope)`

**Options**: [`Grapple.Scope`](#grapplescope) (optional, default: `config.scope`)

**Examples**

```lua
-- Reset tags for the current scope
require("grapple").reset()

-- Reset tags for a specified scope
require("grapple").reset("global")
```

## Suggested Keymaps

#### Anonymous tag keymaps

```lua
vim.keymap.set("n", "<leader>m", require("grapple").toggle, {})
```

#### Named tag keymaps

```lua
vim.keymap.set("n", "<leader>j", function()
    require("grapple").select({ key = "{name}" })
end, {})

vim.keymap.set("n", "<leader>J", function()
    require("grapple").toggle({ key = "{name}" })
end, {})
```

## Integrations

### [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim)

A simple lualine component called `grapple` is provided to show whether a buffer is tagged or not. When a buffer is tagged, the key of the tag will be displayed.

**Untagged buffer**

<img width="240" alt="Screen Shot 2022-11-01 at 07 02 09" src="https://user-images.githubusercontent.com/2467016/199238779-955bd8f3-f406-4a61-b027-ac64d049481a.png">

**Tagged buffer**

<img width="240" alt="Screen Shot 2022-11-01 at 07 02 38" src="https://user-images.githubusercontent.com/2467016/199238764-96678f97-8603-45d9-ba2e-9a512ce93727.png">

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

### [resession.nvim](https://github.com/stevearc/resession.nvim)

Support is available to use [resession.nvim](https://github.com/stevearc/resession.nvim) for persisting tag state.

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

## Grapple Types

<details open>
<summary>Type Definitions</summary>

### `Grapple.Options`

Options available for most top-level tagging actions (e.g. tag, untag, select, toggle, etc).

**Type**: `table`

#### `options.buffer`

**Type**: `integer`

#### `options.file_path`

**Type**: `string`

#### `options.key`

**Type**: [`Grapple.TagKey`](#grappletagkey)

---

### `Grapple.Tag`

A tag contains two pieces of information: the absolute `file_path` of the tagged file, and the last known `cursor` location. A tag is stored in a tag table with a [`Grapple.TagKey`](#grappletagkey), but can only be deterministically identified by its `file_path`.

**Type**: `table`

#### `tag.file_path`

**Type**: `string`

#### `tag.cursor`

**Type**: `integer[2]` (row, column)

---

### `Grapple.TagKey`

A tag may be referenced as an [anonymous tag](#anonymous-tags) by its index (`integer`) or a [named tag](#named-tags) by its key (`string`).

**Type**: `integer` | `string`

---

### `Grapple.Scope`

A scope determines how tags are separated for a given project. There are several builtin options available as [`Grapple.ScopeType`](#grapplescopetype). If the builtin options don't suit a particular use-case, a [`Grapple.ScopeResolver`](#grapplescoperesolver) is also permitted for finer control. Finally, a scope can also be a `string` directory path.

**Type**: [`Grapple.ScopeType`](#grapplescopetype) | [`Grapple.ScopeResolver`](#grapplescoperesolver) | `string`

---

### `Grapple.ScopeType`

A default set of builtin scope resolution methods.

**Type**: `enum`

#### `NONE`

**Value**: `"none"`

#### `GLOBAL`

**Value**: `"global"`

#### `DIRECTORY`

**Value**: `"directory"`

#### `LSP`

**Value**: `"lsp"`

---

### `Grapple.ScopeResolver`

A function that should return a directory path, which is used to determine what scope tags are saved in.

**Type**: `fun(): string`

</details>

## Inspiration and Thanks

* tjdevries [vlog.nvim](https://github.com/tjdevries/vlog.nvim)
* ThePrimeagen's [harpoon](https://github.com/ThePrimeagen/harpoon)
* kwarlwang's [bufjump.nvim](https://github.com/kwkarlwang/bufjump.nvim)
