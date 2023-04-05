# Grapple.nvim

![grapple_showcase](https://user-images.githubusercontent.com/2467016/207667062-13883515-fd21-4d40-be87-656665de3d0e.gif)

_Theme: [kanagawa](https://github.com/rebelot/kanagawa.nvim)_

## Introduction

Grapple is a plugin that aims to provide immediate navigation to important files (and their last known cursor location) by means of persistent [file tags](#file-tags) within a [project scope](#project-scopes). Tagged files can be bound to a [keymap](#suggested-keymaps) or selected from within an editable [popup menu](#popup-menu).

See the [quickstart](#quickstart) section to get started.

## Features

* **Project scoped** file tagging for immediate navigation
* **Persistent** cursor tracking for tagged files
* **Popup** menu to manage tags and scopes as regular text
* **Integration** with [portal.nvim](https://github.com/cbochs/portal.nvim) for additional jump options

## Requirements

* [Neovim >= 0.8](https://github.com/neovim/neovim/releases/tag/v0.8.0)
* Neovim >= 0.9 - optional, for [floating window title](https://github.com/neovim/neovim/issues/17458)
* [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## Quickstart

- [Install](#installation) Grapple.nvim using your preferred package manager
- Add a keybind to `tag`, `untag`, or `toggle` a tag. For example,

```lua
vim.keymap.set("n", "<leader>m", require("grapple").toggle)
```

**Next steps**

- Check out the default settings in the [settings](#settings) section
- View your tags [in a popup](#popup-menu) using `:GrapplePopup tags`
- Know when a file is tagged by adding [statusline component](#statusline)
- Choose a [builtin](#project-scopes) scope or try your hand at creating a [custom](#scope-api) scope to store your tags
- Explore the [Grapple](#grapple-api) and [Scope](#scope-api) APIs

## Installation

<details>
<summary>lazy.nvim</summary>

```lua
{
    "cbochs/grapple.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
}
```

</details>

<details>
<summary>packer</summary>

```lua
use {
    "cbochs/grapple.nvim",
    requires = { "nvim-lua/plenary.nvim" },
}
```

</details>

<details>
<summary>vim-plug</summary>

```vim
Plug "nvim-lua/plenary.nvim"
Plug "cbochs/grapple.nvim"
```

</details>

## Settings

The following are the default settings for Grapple. **Setup is not required**, but settings may be overridden by passing them as table arguments to the `grapple#setup` function.

<details>
<summary>Default Settings</summary>

```lua
require("grapple").setup({
    ---@type "debug" | "info" | "warn" | "error"
    log_level = "warn",

    ---Can be either the name of a builtin scope resolver,
    ---or a custom scope resolver
    ---@type string | Grapple.ScopeResolver
    scope = "git",

    ---The save location for tags
    ---@type string
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

</details>

## Usage

### Grapple API

<details>
<summary>Grapple API and Examples</summary>

#### `grapple#tag`

Create a scoped tag on a file or buffer with an (optional) tag key.

**Command**: `:GrappleTag [key={index} or key={name}] [buffer={buffer}] [file_path={file_path}] [scope={scope}]`

**API**: `require("grapple").tag(opts)`

**`opts?`**: [`Grapple.Options`](#grappleoptions)

* **`buffer?`**: `integer` (default: `0`)
* **`file_path?`**: `string` (overrides `buffer`)
* **`key?`**: [`Grapple.TagKey`](#grappletagkey)
* **`scope?`**: [`Grapple.ScopeResolverLike`](#grapplescoperesolverlike) (default: `settings.scope`)

**Note**: only one tag can be created _per scope per file_. If a tag already exists for the given file or buffer, it will be overridden with the new tag.

<details>
<summary><b>Examples</b></summary>

```lua
-- Tag the current buffer
require("grapple").tag()

-- Tag a file using its file path
require("grapple").tag({ file_path = "{file_path}" })

-- Tag the current buffer using a specified key
require("grapple").tag({ key = 1 })
require("grapple").tag({ key = "{name}" })

-- Tag the current buffer in a specified scope
require("grapple").tag({ scope = "global" })
```

</details>

#### `grapple#untag`

Remove a scoped tag on a file or buffer.

**Command**: `:GrappleUntag [key={name} or key={index}] [buffer={buffer}] [file_path={file_path}] [scope={scope}]`

**API**: `require("grapple").untag(opts)`

**`opts`**: [`Grapple.Options`](#grappleoptions) (one of)

* **`buffer?`**: `integer` (default: `0`)
* **`file_path?`**: `string` (overrides `buffer`)
* **`key?`**: [`Grapple.TagKey`](#grappletagkey) (overrides `buffer` and `file_path`)
* **`scope?`**: [`Grapple.ScopeResolverLike`](#grapplescoperesolverlike) (default: `settings.scope`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Untag the current buffer
require("grapple").untag()

-- Untag a file using its file path
require("grapple").untag({ file_path = "{file_path}" })

-- Untag a file using its tag key
require("grapple").untag({ key = 1 })
require("grapple").untag({ key = "{name}" })

-- Untag a the current buffer from a scope
require("grapple").untag({ scope = "global" })
```

</details>

#### `grapple#toggle`

Toggle a tag or untag on a file or buffer.

**Command**: `:GrappleToggle [key={index} or key={name}] [buffer={buffer}] [file_path={file_path}] [scope={scope}]`

**API**: `require("grapple").toggle(opts)`

**`opts`**: [`Grapple.Options`](#grappleoptions)

* **`buffer?`**: `integer` (default: `0`)
* **`file_path?`**: `string` (overrides `buffer`)
* **`key?`**: [`Grapple.TagKey`](#grappletagkey) (behaviour inherited from [grapple#tag](#grappletag) and [grapple#untag](#grappleuntag))
* **`scope?`**: [`Grapple.ScopeResolverLike`](#grapplescoperesolverlike)

<details>
<summary><b>Examples</b></summary>

```lua
-- Toggle a tag on the current buffer
require("grapple").toggle()
```

</details>

#### `grapple#select`

Select and open a tagged file or buffer in the current window.

**Command**: `:GrappleSelect [key={index} or key={name}]`

**API**: `require("grapple").select(opts)`

**`opts`**: [`Grapple.Options`](#grappleoptions) (one of)

* **`buffer?`**: `integer`
* **`file_path?`**: `string`
* **`key?`**: [`Grapple.TagKey`](#grappletagkey) (preferred)

<details>
<summary><b>Examples</b></summary>

```lua
-- Select an anonymous (numbered) tag
require("grapple").select({ key = 1 })

-- Select a named tag
require("grapple").select({ key = "{name}" })
```

</details>

#### `grapple#find`

Attempt to find a scoped tag.

**API**: `require("grapple").find(opts)`

**`returns`**: [`Grapple.Tag`](#grappletag-1) | `nil`

**`opts?`**: [`Grapple.Options`](#grappleoptions) (one of)

* **`buffer?`**: `integer` (default: `0`)
* **`file_path?`**: `string` (overrides `buffer`)
* **`key?`**: [`Grapple.TagKey`](#grappletagkey) (overrides `buffer` and `file_path`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Find the tag associated with the current buffer
require("grapple").find()
```

</details>

#### `grapple#key`

Attempt to find the key associated with a file tag.

**API**: `require("grapple").key(opts)`

**`returns`**: [`Grapple.TagKey`](#grappletagkey) | `nil`

**`opts?`**: [`Grapple.Options`](#grappleoptions) (one of)

* **`buffer?`**: `integer` (default: `0`)
* **`file_path?`**: `string` (overrides `buffer`)
* **`key?`**: [`Grapple.TagKey`](#grappletagkey) (overrides `buffer` and `file_path`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Find the tag key associated with the current buffer
require("grapple").key()
```

</details>

#### `grapple#exists`

**API**: `require("grapple").exists(opts)`

**`returns`**: `boolean`

**`opts?`**: [`Grapple.Options`](#grappleoptions) (one of)

* **`buffer?`**: `integer` (default: `0`)
* **`file_path?`**: `string` (overrides `buffer`)
* **`key?`**: [`Grapple.TagKey`](#grappletagkey) (overrides `buffer` and `file_path`)
* **`scope?`**: [`Grapple.ScopeResolverLike`](#grapplescoperesolverlike) (default: `settings.scope`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Check whether the current buffer is tagged or not
require("grapple").exists()

-- Check for a tag in a different scope
require("grapple").exists({ scope = "global" })
```

</details>

#### `grapple#cycle`

Cycle through and select from the available tagged files in a scoped tag list.

**Command**: `:GrappleCycle {direction}`

**API**:

* `require("grapple").cycle(direction)`
* `require("grapple").cycle_backward()`
* `require("grapple").cycle_forward()`

**`direction`**: `"backward"` | `"forward"`

**Note**: only [anonymous tags](#anonymous-tags) are cycled through, not [named tags](#named-tags).

<details>
<summary><b>Examples</b></summary>

```lua
-- Cycle to the previous tagged file
require("grapple").cycle_backward()

-- Cycle to the next tagged file
require("grapple").cycle_forward()
```

</details>

#### `grapple#tags`

Return all tags for a given project scope.

**Command**: `:Grapple tags {scope}`

**API**: `require("grapple").tags(scope)`

**`scope?`**: [`Grapple.ScopeResolverLike`](#grapplescoperesolverlike) (default: `settings.scope`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Get all tags for the current scope
require("grapple").tags()
```

</details>

#### `grapple#reset`

Clear all tags for a given project scope.

**Command**: `:GrappleReset [scope]`

**API**: `require("grapple").reset(scope)`

**`scope?`**: [`Grapple.ScopeResolverLike`](#grapplescoperesolverlike) (default: `settings.scope`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Reset tags for the current scope
require("grapple").reset()

-- Reset tags for a specified scope
require("grapple").reset("global")
```

</details>

#### `grapple#quickfix`

Open the quickfix menu and populate the quickfix list with a project scope's tags.

**API**: `require("grapple").quickfix(scope)`

**`scope?`**: [`Grapple.ScopeResolverLike`](#grapplescoperesolverlike) (default: `settings.scope`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Open the quickfix menu for the current scope
require("grapple").quickfix()

-- Open the quickfix menu for a specified scope
require("grapple").quickfix("global")
```

</details>

</details>

### Scope API

<details>
<summary>Scope API and Examples</summary>

#### `grapple.scope#resolver`

Create a scope resolver that generates a project scope.

**API**: `require("grapple.scope").resolver(scope_callback, opts)`

**`returns`**: [`Grapple.ScopeResolver`](#grapplescoperesolver-1)

**`scope_callback`**: [`Grapple.ScopeFunction`](#grapplescopefunction) | [`Grapple.ScopeJob`](#grapplescopejob)

**`opts?`**: [`Grapple.ScopeOptions`](#grapplescopeoptions)

* **`cache?`**: `boolean` | `string` | `string[]` | `integer` (default: `true`)
* **`persist?`**: `boolean` (default: `true`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Create a scope resolver that updates when the current working
-- directory changes
require("grapple.scope").resolver(function()
    return vim.fn.getcwd()
end, { cache = "DirChanged" })

-- Create an scope resolver that asynchronously runs the "echo"
-- shell command and uses its output as the resolved scope
require("grapple.scope").resolver({
    command = "echo",
    args = [ "hello_world" ],
    cwd = vim.fn.getcwd(),
    on_exit = function(job, return_value)
        return job:result()[1]
    end
})
```

</details>

#### `grapple.scope#root`

Create a scope resolver that generates a project scope by looking upwards for directories containing a specific file or directory.

**API**: `require("grapple.scope").root(root_names, opts)`

**`returns`**: [`Grapple.ScopeResolver`](#grapplescoperesolver-1)

**`root_names`**: `string` | `string[]`

**`opts?`**: [`Grapple.ScopeOptions`](#grapplescopeoptions)

* **`cache?`**: `boolean` | `string` | `string[]` | `integer` (default: `"DirChanged"`)
* **`persist?`**: `boolean` (default: `true`)

**Note**: it is recommended to use this with a **[fallback scope resolver](#grapplescopefallback)** to guarantee that a scope is found.

<details>
<summary><b>Examples</b></summary>

```lua
-- Create a root scope resolver that looks for a directory containing
-- a "Cargo.toml" file
require("grapple.scope").root("Cargo.toml")

-- Create a root scope resolver that falls back to using the initial working
-- directory for your neovim session
require("grapple.scope").fallback({
    require("grapple.scope").root("Cargo.toml"),
    require("grapple").resolvers.static,
})
```

</details>

#### `grapple.scope#root_from_buffer`

Create a scope resolver that generates a project scope by looking upwards for directories containing a specific file or directory _from the current buffer_.

**API**: `require("grapple.scope").root(root_names, opts)`

**`returns`**: [`Grapple.ScopeResolver`](#grapplescoperesolver-1)

**`root_names`**: `string` | `string[]`

**`opts?`**: [`Grapple.ScopeOptions`](#grapplescopeoptions)

* **`cache?`**: `boolean` | `string` | `string[]` | `integer` (default: `"BufEnter"`)
* **`persist?`**: `boolean` (default: `true`)

**Note**: it is recommended to use this with a **[fallback scope resolver](#grapplescopefallback)** to guarantee that a scope is found.

<details>
<summary><b>Examples</b></summary>

```lua
-- Create a buffer-based root scope resolver that looks for a directory
-- containing a "Cargo.toml" file
require("grapple.scope").root_from_buffer("Cargo.toml")

-- Create a buffer-based root scope resolver that falls back to using
-- the initial working directory for your neovim session
require("grapple.scope").fallback({
    require("grapple.scope").root_from_buffer("Cargo.toml"),
    require("grapple").resolvers.static,
})
```

</details>

#### `grapple.scope#fallback`

Create a scope resolver that generates a project scope by attempting to get the project scope of other scope resolvers, in order.

**API**: `require("grapple.scope").fallback(scope_resolvers, opts)`

**`returns`**: [`Grapple.ScopeResolver`](#grapplescoperesolver-1)

**`scope_resolvers`**: [`Grapple.ScopeResolver[]`](#grapplescoperesolver-1)

**`opts?`**: [`Grapple.ScopeOptions`](#grapplescopeoptions)

* **`cache?`**: `boolean` | `string` | `string[]` | `integer` (default: `false`)
* **`persist?`**: `boolean` (default: `true`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Create a fallback scope resolver that first tries to use the LSP for a scope
-- path, then looks for a ".git" repository, and finally falls back on using
-- the initial working directory that neovim was started in
require("grapple.scope").fallback({
    require("grapple").resolvers.lsp_fallback,
    require("grapple").resolvers.git_fallback,
    require("grapple").resolvers.static
})
```

</details>

#### `grapple.scope#suffix`

Create a scope resolver that takes in two scope resolvers: a **path resolver** and a **suffix** resolver. If the scope determined from the path resolver is not nil, then the scope from the suffix resolver may be appended to it. Useful in situations where you may want to append additional project information (i.e. the current git branch).

**API**: `require("grapple.scope").suffix(path_resolver, suffix_resolver, opts)`

**`returns`**: [`Grapple.ScopeResolver`](#grapplescoperesolver-1)

**`path_resolver`**: [`Grapple.ScopeResolver`](#grapplescoperesolver-1)

**`suffix_resolver`**: [`Grapple.ScopeResolver`](#grapplescoperesolver-1)

**`opts?`**: [`Grapple.ScopeOptions`](#grapplescopeoptions)

* **`cache?`**: `boolean` | `string` | `string[]` | `integer` (default: `false`)
* **`persist?`**: `boolean` (default: `true`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Create a suffix scope resolver that duplicates a static resolver
-- and appends it to itself (e.g. "asdf#asdf")
require("grapple.scope").suffix(
    require("grapple.scope").static("asdf"),
    require("grapple.scope").static("asdf"),
)
```

</details>

#### `grapple.scope#static`

Create a scope resolver that simply returns a static string. Useful when creating sub-groups with [`grapple.scope#suffix`](#grapplescopesuffix).

**API**: `require("grapple.scope").static(plain_string, opts)`

**`returns`**: [`Grapple.ScopeResolver`](#grapplescoperesolver-1)

**`plain_string`**: `string`

**`opts?`**: [`Grapple.ScopeOptions`](#grapplescopeoptions)

* **`cache?`**: `boolean` | `string` | `string[]` | `integer` (default: `false`)
* **`persist?`**: `boolean` (default: `true`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Create a static scope resolver that simply returns "I'm a teapot"
require("grapple.scope").static("I'm a teapot")

-- Create a suffix scope resolver that appends the suffix "commands"
-- to the end of the git scope resolver
require("grapple.scope").suffix(
    require("grapple").resolvers.git,
    require("grapple.scope").static("commands")
)
```

</details>

#### `grapple.scope#invalidate`

Clear the cached project scope, forcing the next call to get the project scope to re-resolve and re-instantiate the cache.

**API**: `require("grapple.scope").invalidate(scope_resolver)`

**`scope_resolver`**: [`Grapple.ScopeResolverLike`](#grapplescoperesolverlike)

<details>
<summary><b>Examples</b></summary>

```lua
local my_resolver = require("grapple.scope").resolver(function()
    return vim.fn.getcwd()
end)

-- Invalidate a cached scope associated with a scope resolver
require("grapple.scope").invalidate(my_resolver)
```

</details>

#### `grapple.scope#update`

Update the cached project scope. Unlike [`grapple.scope#invalidate`](#grapplescopeinvalidate) which lazily updates the project scope, this immediately updates the cached project scope.

**API**: `require("grapple.scope").update(scope_resolver)`

**`scope_resolver`**: [`Grapple.ScopeResolverLike`](#grapplescoperesolverlike)

<details>
<summary><b>Examples</b></summary>

```lua
local my_resolver = require("grapple.scope").resolver(function()
    return vim.fn.getcwd()
end)

-- Update a cached scope associated with a scope resolver
require("grapple.scope").update(my_resolver)
```

</details>

</details>

## File Tags

A **tag** is a persistent tag on a file or buffer. It is a means of indicating a file you want to return to. When a file is tagged, Grapple will save your cursor location so that when you jump back, your cursor is placed right where you left off. In a sense, tags are like file-level marks (`:h mark`).

There are a couple types of tag types available, each with a different use-case in mind. The options available are [anonymous](#anonymous-tags) and [named](#named-tags) tags. In addition, tags are [scoped](#project-scopes) to prevent tags in one project polluting the namespace of another. For command and API information, please see the [Grapple API](#grapple-api). For additional examples, see the [Wiki](https://github.com/cbochs/grapple.nvim/wiki/File-Tags).

### Anonymous Tags

This is the _default_ tag type. Anonymous tags are added to a list, where they may be selected by index, cycled through, or jumped to using the [tag popup menu](#tag-popup-menu) or plugins such as [portal.nvim](https://github.com/cbochs/portal.nvim).

Anonymous tags are similar to those found in plugins like [harpoon](https://github.com/ThePrimeagen/harpoon).

### Named Tags

Tags that are given a name are considered to be **named tags**. These tags will not be cycled through with `cycle_{backward, forward}`, but instead must be explicitly selected.

Named tags are useful if you want one or two keymaps to be used for tagging and selecting. For example, the pairs `<leader>j/J` and `<leader>k/K` to `select/toggle` a file tag (see: [suggested keymaps](#named-tag-keymaps)).

## Project Scopes

A **scope** is a means of namespacing tags to a specific project. During runtime, scopes are typically resolved into an absolute directory path (i.e. current working directory), which - in turn - is used as the "root" location for a set of tags.

Project scopes are _cached by default_, and will only update when the cache is [explicitly invalidated](#grapplescopeinvalidate), an associated ([`:h autocmd`](https://neovim.io/doc/user/autocmd.html)) is triggered, or at a specified interval. For example, the `static` scope never updates once cached; the `directory` scope only updates on `DirChanged`; and the `lsp` scope updates on either `LspAttach` or `LspDetach`.

A **project scope** is determined by means of a **[scope resolver](#grapplescoperesolver)**. The builtin options are as follows:

* `none`: tags are ephemeral and deleted on exit
* `global`: tags are scoped to a global namespace
* `static`: tags are scoped to neovim's initial working directory
* `directory`: tags are scoped to the current working directory
* `lsp`: tags are scoped using the `root_dir` of the current buffer's attached LSP server, **fallback**: `static`
* `git`: tags are scoped to the current git repository, **fallback**: `static`
* `git_branch`: tags are scoped to the current git repository and branch (async), **fallback**: `static`

There are three additional scope resolvers which should be preferred when creating a **[fallback scope resolver](#grapplescopefallback)** or **[suffix scope resolver](#grapplescopesuffix)**. These resolvers act identically to their similarly named counterparts, but do not have default fallbacks.

* `lsp_fallback`: the same as `lsp`, but without a fallback
* `git_fallback`: the same as `git`, but without a fallback
* `git_branch_suffix`: resolves suffix (branch) for `git_branch` (async)

It is also possible to create your own **custom scope resolver**. For the available scope resolver types, please see the [Scope API](#scope-api). For additional examples, see the [Wiki](https://github.com/cbochs/grapple.nvim/wiki/Project-Scopes).

<details>
<summary><b>Examples</b></summary>

```lua
-- Setup using a builtin scope resolver
require("grapple").setup({
    scope = require("grapple").resolvers.git
})

-- Setup using a custom scope resolver
require("grapple").setup({
    scope = require("grapple.scope").resolver(function()
        return vim.fn.getcwd()
    end, { cache = "DirChanged" })
})
```

</details>

## Popup Menu

A popup menu is available to enable easy management of tags and scopes. The opened buffer (filetype: `grapple`) can be modified like a regular buffer; meaning items can be selected, modified, reordered, or deleted with well-known vim motions. Currently, there are two available popup menus: one for [tags](#tag-popup-menu) and another for [scopes](#scope-popup-menu).

<img width="1038" alt="Screenshot 2022-12-15 at 09 05 07" src="https://user-images.githubusercontent.com/2467016/207909857-98e7bc5d-8b48-4650-acb9-5993dde87a0f.png">

### Tag Popup Menu

The **tags popup menu** opens a floating window containing all the tags within a specified scope. The floating window can be exited with either `q`, `<esc>`, or any keybinding that is bound to `<esc>`. Several actions are available within the tags popup menu:
* **Selection**: a tag can be selected by moving to its corresponding line and pressing enter (`<cr>`)
* **Deletion**: a tag (or tags) can be removed by deleting them from the popup menu (i.e. NORMAL `dd` and VISUAL `d`)
* **Reordering**: an [anonymous tag](#anonymous-tags) (or tags) can be reordered by moving them up or down within the popup menu. Ordering is determined by the tags position within the popup menu: top (first index) to bottom (last index)
* **Renaming**: a [named tag](#named-tags) can be renamed by editing its key value between the `[` square brackets `]`
* **Quickfix (`<c-q>`)**: all tags will be [sent to the quickfix list](#grapplequickfix), the popup menu closed, and the quickfix menu opened
* **Split (`<c-v>`)**: similar to tag selection, but the tagged file opened in a vertical split

**Command**: `:GrapplePopup tags`

**API**: `require("grapple").popup_tags(scope)`

**`scope?`**: [`Grapple.ScopeResolverLike`](#grapplescoperesolverlike) (default: `settings.scope`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Open the tags popup menu in the current scope
require("grapple").popup_tags()

-- Open the tags popup menu in a different scope
require("grapple").popup_tags("global")
```

</details>

### Scope Popup Menu

The **scopes popup menu** opens a floating window containing all the loaded project scopes. A scope (or scopes) can be deleted with typical vim edits (i.e. NORMAL `dd` and VISUAL `d`). The floating window can be exited with either `q` or any keybinding that is bound to `<esc>`. The total number of tags within a scope will be displayed to the left of the project scope.

**Command**: `:GrapplePopup scopes`

**API**: `require("grapple.popup_scopes()`

<details>
<summary><b>Examples</b></summary>

```lua
-- Open the scopes popup menu
require("grapple").popup_scopes()
```

</details>

## Persistent State

Grapple saves all [project scopes](#project-scopes) to a common directory. This directory is aptly named `grapple` and lives in Neovim's `"data"` directory (see: [`:h standard-path`](https://neovim.io/doc/user/starting.html#standard-path)). Each non-empty scope (scope contains at least one item) will be saved as an individiual scope file; serialized as a JSON blob, and named using the resolved scope's path.

Each tag in a scope will contain two pieces of information: the absolute `file path` of the tagged file and its last known `cursor` location.

When a user starts Neovim, no scopes are initially loaded. Instead, Grapple will wait until the user requests a project scope (e.g. [tagging a file](#grappletag) or opening the [tags popup menu](#tag-popup-menu)). At that point, one of three things can occur:
* the scope is **already loaded**, nothing is needed to be done
* the scope has **not been loaded**, attempt to load scope state from its associated scope file
* the scope file was **not found**, initialize the scope state as an empty table

## Suggested Keymaps

#### Anonymous tag keymaps

```lua
vim.keymap.set("n", "<leader>m", require("grapple").toggle)
```

#### Named tag keymaps

```lua
vim.keymap.set("n", "<leader>j", function()
    require("grapple").select({ key = "{name}" })
end)

vim.keymap.set("n", "<leader>J", function()
    require("grapple").toggle({ key = "{name}" })
end)
```

## Integrations

### Statusline

A statusline component can be easily added to show whether a buffer is tagged or not by using either (or both) [`grapple#key`](#grapplekey) and [`grapple#find`](#grapplefind).

**Simple [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) statusline**

```lua
require("lualine").setup({
    sections = {
        lualine_b = {
            {
                require("grapple").key,
                cond = require("grapple").exists
            }
        }
    }
})
```

**Slightly nicer [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) statusline**

```lua
require("lualine").setup({
    sections = {
        lualine_b = {
            {
                function()
                    local key = require("grapple").key()
                    return "  [" .. key .. "]"
                end,
                cond = require("grapple").exists,
            }
        }
    }
})
```

### Telescope

You can use telescope to search through your tagged files instead of the built in pop up menu.

Load the extension via
```lua
require("telescope").load_extension("grapple")
```
Then use this command to see the grapple tags for the project in a telescope window
```
:Telescope grapple hooks
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
* **`scope`**: [`Grapple.ScopeResolverLike`](#grapplescoperesolverlike)

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

Options available when creating custom scope resolvers. Builtin resolvers

Giving a scope resolver a `key` will allow it to be identified within the `require("grapple").resolvers` table. For a scope to persisted, the `persist` options must be set to `true`; otherwise, any scope that is resolved by the scope resolver will be deleted when Neovim exits.

In addition to scope persistence, a scope may also be cached for faster access during a Neovim session. The `cache` option may be one of the following:
* `cache = true`: project scope is resolved once and cached until explicitly invalidated
* `cache = false` project scope is never cached and must always be resolved
* `cache = string | string[]` project scope is cached and invalidated when a given autocommand event is triggered (see: [`:h autocmd`](https://neovim.io/doc/user/autocmd.html))
* `cache = integer` project scope is cached and updated on a given interval (in milliseconds)

**Type**: `table`

* **`cache`**: `boolean` | `string` | `string[]` | `integer`
* **`persist`**: `boolean`

---

### `Grapple.ScopeFunction`

A _synchronous_ scope resolving callback function. Used when creating a scope resolver.

**Type**: `fun(): Grapple.Scope | nil`

---

### `Grapple.ScopeJob`

An _asynchronous_ scope resolving callback command. Used when creating a scope resolver. The `command` and `args` should specify a complete shell command to execute. The `on_exit` callback should understand how to parse the output of the command into a project scope ([`Grapple.Scope`](#grapplescope)), or return `nil` on execution failure. The `cwd` must be specified as the directory which the command should be executed in.

**Type**: `table`

* **`command`**: `string`
* **`args`**: `string[]`
* **`cwd`**: `string`
* **`on_exit`**: `fun(job, return_value): Grapple.Scope | nil`

---

### `Grapple.ScopeResolver`

Resolves into a [`Grapple.Scope`](#grapplescope). Should be created using the Scope API (e.g. [`grapple.scope#resolver`](#grapplescoperesolver)). For more information, see [project scopes](#project-scopes).

**Type**: `table`

* **`key`**: `integer`
* **`callback`**: [`Grapple.ScopeFunction`](#grapplescopefunction) | [`Grapple.ScopeJob`](#grapplescopejob)
* **`cache`**: `boolean` | `string` | `string[]` | `integer`
* **`autocmd`**: `number` | `nil`

---

### `Grapple.ScopeResolverLike`

Either the name of a [builtin](#project-scopes) scope resolver, or a scope resolver.

**Type**: `string` | [`Grapple.ScopeResolver`](#grapplescoperesolver-1)

---

### `Grapple.Scope`

The name of a project scope that has been resolved from a [`Grapple.ScopeResolver`](#grapplescoperesolver-1).

**Type**: `string`

</details>

## Inspiration and Thanks

* tjdevries [vlog.nvim](https://github.com/tjdevries/vlog.nvim)
* ThePrimeagen's [harpoon](https://github.com/ThePrimeagen/harpoon)
* kwarlwang's [bufjump.nvim](https://github.com/kwkarlwang/bufjump.nvim)
