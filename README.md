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
* Neovim >= 0.9 - optional, for [floating window title](https://github.com/neovim/neovim/issues/17458)
* [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## Installation

### [packer](https://github.com/wbthomason/packer.nvim)

```lua
use {
    "cbochs/grapple.nvim",
    requires = { "nvim-lua/plenary.nvim" },
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```
Plug "cbochs/grapple.nvim"
```

## Configuration

Below is the default configuration. Setup is **not required**, but may be overridden by invoking `require("grapple").setup`.

```lua
require("grapple").setup({
    ---@type "debug" | "info" | "warn" | "error"
    log_level = "warn",

    ---The scope used when creating, selecting, and deleting tags
    ---@type Grapple.ScopeKey | Grapple.ScopeResolver
    scope = "static",

    ---The save location for tags
    save_path = tostring(Path:new(vim.fn.stdpath("data")) / "grapple"),

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

This is the _default_ tag type. Anonymous tags are added to a list, where they may be selected by index, cycled through, or jumped to using the [tag popup menu](#tag-popup-menu) or plugins such as [portal.nvim](https://github.com/cbochs/portal.nvim).

Anonymous tags are similar to those found in plugins like [harpoon](https://github.com/ThePrimeagen/harpoon).

### Named Tags

Tags that are given a name are considered to be **named tags**. These tags will not be cycled through with `cycle_{backward, forward}`, but instead must be explicitly selected.

Named tags are useful if you want one or two keymaps to be used for tagging and selecting. For example, the pairs `<leader>j/J` and `<leader>k/K` to `select/toggle` a file tag (see: [suggested keymaps](#named-tag-keymaps)).

### Tag Scopes

A **scope** is a means of namespacing tags to a specific project. During runtime, scopes are resolved into a file path, which - in turn - are used as the "root" location for a set of tags.

Scope paths are _cached by default_, and will only update when triggered by a provided autocommand event ([`:h autocmd`](https://neovim.io/doc/user/autocmd.html)). For example, the `static` scope never updates once cached; the `directory` scope only updates on `DirChanged`; and the `lsp` scope updates on either `LspAttach` or `LspDetach`.

A **scope path** is determined by means of a **[scope resolver](#grapplescoperesolver)**. The builtin options are as follows:

* `none`: Tags are ephemeral and deleted on exit
* `global`: Tags are scoped to a global namespace
* `directory`: Tags are scoped to the current working directory
* `static`: Tags are scoped to neovim's initial working directory
* `lsp`: Tags are scoped using the `root_dir` of the current buffer's attached LSP server

**Used during plugin setup**

```lua
-- Setup using a scope resolver's name
require("grapple").setup({
    scope = "global"
})

-- Or, using the scope resolver itself
require("grapple").setup({
    scope = require("grapple.scope").resolvers.global
})
```

For usage and examples, please see [scope usage](#scope-usage) and the [Wiki](https://github.com/cbochs/grapple.nvim/wiki/Tag-Scopes), respectively.

### Usage

<details open>
<summary>Usage</summary>

#### `grapple#tag`

Create a scoped tag on a file or buffer with an (optional) tag key.

**Command**: `:GrappleTag [key={index} or key={name}] [buffer={buffer}] [file_path={file_path}]`

**API**: `require("grapple").tag(opts)`

**`opts?`**: [`Grapple.Options`](#grappleoptions)

* **`buffer?`**: `integer` (default: `0`)
* **`file_path?`**: `string` (overrides `buffer`)
* **`key?`**: [`Grapple.TagKey`](#grappletagkey)

**Note**: only one tag can be created _per scope per file_. If a tag already exists for the given file or buffer, it will be overridden with the new tag.

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

#### `grapple#untag`

Remove a scoped tag on a file or buffer.

**Command**: `:GrappleUntag [key={name} or key={index}] [buffer={buffer}] [file_path={file_path}]`

**API**: `require("grapple").untag(opts)`

**`opts`**: [`Grapple.Options`](#grappleoptions) (one of)

* **`buffer?`**: `integer` (default: `0`)
* **`file_path?`**: `string` (overrides `buffer`)
* **`key?`**: [`Grapple.TagKey`](#grappletagkey) (overrides `buffer` and `file_path`)

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

#### `grapple#toggle`

Toggle a tag or untag on a file or buffer.

**Command**: `:GrappleToggle [key={index} or key={name}] [buffer={buffer}] [file_path={file_path}]`

**API**: `require("grapple").toggle(opts)`

**`opts`**: [`Grapple.Options`](#grappleoptions)

* **`buffer?`**: `integer` (default: `0`)
* **`file_path?`**: `string` (overrides `buffer`)
* **`key?`**: [`Grapple.TagKey`](#grappletagkey) (behaviour inherited from [grapple#tag](#grappletag) and [grapple#untag](#grappleuntag))

**Examples**

```lua
-- Toggle a tag on the current buffer
require("grapple").toggle()
```

#### `grapple#select`

Select and open a tagged file or buffer in the current window.

**Command**: `:GrappleSelect [key={index} or key={name}]`

**API**: `require("grapple").select(opts)`

**`opts`**: [`Grapple.Options`](#grappleoptions) (one of)

* **`buffer?`**: `integer`
* **`file_path?`**: `string`
* **`key?`**: [`Grapple.TagKey`](#grappletagkey) (preferred)

**Examples**

```lua
-- Select an anonymous (numbered) tag
require("grapple").select({ key = 1 })

-- Select a named tag
require("grapple").select({ key = "{name}" })
```

#### `grapple#find`

Attempt to find a scoped tag.

**API**: `require("grapple").find(opts)`

**`returns`**: [`Grapple.Tag`](#grappletag-1) | `nil`

**`opts?`**: [`Grapple.Options`](#grappleoptions) (one of)

* **`buffer?`**: `integer` (default: `0`)
* **`file_path?`**: `string` (overrides `buffer`)
* **`key?`**: [`Grapple.TagKey`](#grappletagkey) (overrides `buffer` and `file_path`)

**Examples**

```lua
-- Find the tag associated with the current buffer
require("grapple").find()
```

#### `grapple#key`

Attempt to find the key associated with a file tag.

**API**: `require("grapple").key(opts)`

**`returns`**: [`Grapple.TagKey`](#grappletagkey) | `nil`

**`opts?`**: [`Grapple.Options`](#grappleoptions) (one of)

* **`buffer?`**: `integer` (default: `0`)
* **`file_path?`**: `string` (overrides `buffer`)
* **`key?`**: [`Grapple.TagKey`](#grappletagkey) (overrides `buffer` and `file_path`)

**Examples**

```lua
-- Find the tag key associated with the current buffer
require("grapple").key()
```

#### `grapple#exists`

**API**: `require("grapple").exists(opts)`

**`returns`**: `boolean`

**`opts?`**: [`Grapple.Options`](#grappleoptions) (one of)

* **`buffer?`**: `integer` (default: `0`)
* **`file_path?`**: `string` (overrides `buffer`)
* **`key?`**: [`Grapple.TagKey`](#grappletagkey) (overrides `buffer` and `file_path`)

**Examples**

```lua
-- Check whether the current buffer is tagged or not
require("grapple").exists()
```

#### `grapple#cycle`

Cycle through and select from the available tagged files in a scoped tag list.

**API**:

* `require("grapple").cycle(direction)`
* `require("grapple").cycle_backward()`
* `require("grapple").cycle_forward()`

**`direction`**: `"backward"` | `"forward"`

**Note**: only [anonymous tags](#anonymous-tags) are cycled through, not [named tags](#named-tags).

**Examples**

```lua
-- Cycle to the previous tagged file
require("grapple").cycle_backward()

-- Cycle to the next tagged file
require("grapple").cycle_forward()
```

#### `grapple#reset`

Clear all tags for a given tag scope.

**Command**: `:GrappleReset [scope]`

**API**: `require("grapple").reset(scope)`

**`scope?`**: [`Grapple.Scope`](#grapplescope) (default: `config.scope`)

**Examples**

```lua
-- Reset tags for the current scope
require("grapple").reset()

-- Reset tags for a specified scope
require("grapple").reset("global")
```

</details>

### Scope Usage

<details open>
<summary>Scope Usage</summary>

#### `grapple.scope#resolver`

Create a scope resolver that generates a scope path.

**API**: `require("grapple.scope").resolver(scope_function, opts)`

**`returns`**: [`Grapple.ScopeResolver`](#grapplescoperesolver-1)

**`scope_function`**: [`Grapple.ScopeFunction`](#grapplescopefunction)

**`opts?`**: [`Grapple.ScopeOptions`](#grapplescopeoptions)

* **`key?`**: `string`
* **`cache?`**: `boolean` | `string` | `string[]` (default: `true`)

**Example**

```lua
-- Create a scope resolver that updates when the current working
-- directory changes
require("grapple.scope").resolver(function()
    return vim.fn.getcwd()
end, { cache = "DirChanged" })
```

#### `grapple.scope#root`

Create a scope resolver that generates a scope path by looking upwards for directories containing a specific file or directory.

**API**: `require("grapple.scope").root(root_names, opts)`

**`returns`**: [`Grapple.ScopeResolver`](#grapplescoperesolver-1)

**`root_names`**: `string` | `string[]`

**`opts?`**: [`Grapple.ScopeOptions`](#grapplescopeoptions)

* **`key?`**: `string`
* **`cache?`**: `boolean` | `string` | `string[]` (default: `"DirChanged"`)

**Example**

```lua
-- Create a root scope resolver that looks for a directory containing
-- a ".git" folder
require("grapple.scope").root(".git")
```

#### `grapple.scope#fallback`

Create a scope resolver that generates a scope path by attempting to get the scope path of other scope resolvers, in order.

**API**: `require("grapple.scope").fallback(...)`

**`returns`**: [`Grapple.ScopeResolver`](#grapplescoperesolver-1)

**`...`**: [`Grapple.ScopeResolver[]`](#grapplescoperesolver-1)

**Example**

```lua
-- Create a fallback scope resolver that first tries to use the LSP for a scope
-- path, then looks for a ".git" repository, and finally falls back on using
-- the initial working directory that neovim was started in
require("grapple.scope").fallback(
    require("grapple.scope").resolvers.lsp,
    require("grapple.scope").root(".git"),
    require("grapple.scope").resolvers.static
)
```

#### `grapple.scope#invalidate`

Clear the cached scope path, forcing the next call to `grapple.scope#get` to resolve the scope path instead of using its previously cached value.

**API**: `require("grapple.scope").invalidate(scooe_resolver)`

**`scope_resolver`**: [`Grapple.ScopeKey`](#grapplescopekey) | [`Grapple.ScopeResolver[]`](#grapplescoperesolver-1)

**Example**

```lua
require("grapple.scope").resolver(function()
    return vim.fn.getcwd()
end, { key = "my resolver" })

-- Invalidate a cached scope by its key name
require("grapple.scope").invalidate("my resolver")
```

</details>

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

**`scope?`**: [`Grapple.Scope`](#grapplescope) (default: `config.scope`)

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

## Persistent Tag State

**todo!(cbochs)**

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

* **`buffer`**: `integer`
* **`file_path`**: `string`
* **`key`**: [`Grapple.TagKey`](#grappletagkey)

---

### `Grapple.Tag`

A tag contains two pieces of information: the absolute `file_path` of the tagged file, and the last known `cursor` location. A tag is stored in a tag table keyed with a [`Grapple.TagKey`](#grappletagkey), but can only be deterministically identified by its `file_path`.

**Type**: `table`

* **`file_path`**: `string`
* **`cursor`**: `integer[2]` (row, column)

---

### `Grapple.TagKey`

A tag may be referenced as an [anonymous tag](#anonymous-tags) by its index (`integer`) or a [named tag](#named-tags) by its key (`string`).

**Type**: `integer` | `string`

---

### `Grapple.ScopeOptions`

Options available when creating custom scope resolvers. Giving a scope resolver a `key` will allow it to be identified within the `require("grapple.scope").resolvers` table. In addition, a scope may also be cached. The `cache` option may be one of the following:
* `cache = true`: scope path is resolved once and cached until explicitly invalidated
* `cache = false` scope path is never cached and must always be resolved
* `cache = string | string[]` scope path is cached and invalidated when a given autocommand event is triggered (see: [`:h autocmd`](https://neovim.io/doc/user/autocmd.html))

**Type**: `table`

* **`key`**: `string`
* **`cache`**: `boolean` | `string` | `string[]`

---

### `Grapple.ScopeKey`

A **[scope resolver](#grapplescoperesolver-1)** is identified by its **scope key** in the `require("grapple.scope").resolvers` table. When not explicitly set in [`Grapple.ScopeOptions`](#grapplescopeoptions), a scope resolver will be appended to the end of the `resolvers` table and the resolver's key will be given that index.

**Type**: `string` | `integer`

---

### `Grapple.ScopePath`

**Type**: `string`

---

### `Grapple.ScopeFunction`

**Type**: `fun(): Grapple.ScopePath | nil`

---

### `Grapple.ScopeResolver`

**Type**: `table`

* **`key`**: [`Grapple.ScopeKey`](#grapplescopekey)
* **`resolve`**: [`Grapple.ScopeFunction`](#grapplescopefunction)
* **`cache`**: `boolean` | `string` | `string[]`
* **`autocmd`**: `number` | `nil`

---

### `Grapple.Scope`

A scope determines how tags are separated for a given project.

**Type**: [`Grapple.ScopeKey`](#grapplescopekey) | [`Grapple.ScopeResolver`](#grapplescoperesolver-1)

</details>

## Inspiration and Thanks

* tjdevries [vlog.nvim](https://github.com/tjdevries/vlog.nvim)
* ThePrimeagen's [harpoon](https://github.com/ThePrimeagen/harpoon)
* kwarlwang's [bufjump.nvim](https://github.com/kwkarlwang/bufjump.nvim)
