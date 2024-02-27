# Grapple.nvim

![grapple_showcase](https://user-images.githubusercontent.com/2467016/207667062-13883515-fd21-4d40-be87-656665de3d0e.gif)

_Theme: [kanagawa](https://github.com/rebelot/kanagawa.nvim)_

## Introduction

Grapple is a plugin that aims to provide immediate navigation to important files (and their last known cursor location).

See the [quickstart](#quickstart) section to get started.

## Features

- **Persistent** cursor tracking for tagged files
- **Scoped** file tagging for immediate navigation
- **Popup** windows to manage tags and scopes as regular text
- **Integration** with [portal.nvim](https://github.com/cbochs/portal.nvim) for additional jump options

## Requirements

- [Neovim >= 0.8](https://github.com/neovim/neovim/releases/tag/v0.9.0)

## Quickstart

- [Install](#installation) Grapple.nvim using your preferred package manager
- Add a keybind to `tag`, `untag`, or `toggle` a tag. For example,

```lua
vim.keymap.set("n", "<leader>m", "<cmd>Grapple toggle<cr>")
vim.keymap.set("n", "<leader>M", "<cmd>Grapple open_tags<cr>"
```

**Next steps**

- Check out the default settings in the [settings](#settings) section
- View your tags with `:Grapple open_tags`
- Choose a scope with `:Grapple open_scopes`
- Add a [statusline component](#statusline)
- Explore the [Grapple](#grapple-api) and [Scope](#scopes-api) APIs

## Installation

<details>
<summary>lazy.nvim</summary>

```lua
{ "cbochs/grapple.nvim" }
```

</details>

<details>
<summary>packer</summary>

```lua
use { "cbochs/grapple.nvim" }
```

</details>

<details>
<summary>vim-plug</summary>

```vim
Plug "cbochs/grapple.nvim"
```

</details>

## Settings

The following are the default settings for Grapple. **Setup is not required**, but settings may be overridden by passing them as table arguments to the `grapple#setup` function.

<details>
<summary>Default Settings</summary>

```lua
require("grapple").setup({
    ---Grapple save location
    ---@type string
    save_path = vim.fs.joinpath(vim.fn.stdpath("data"), "grapple"),

    ---Show icons next to tags or scopes in Grapple windows
    ---@type boolean
    icons = true,

    ---Default scope to use when managing Grapple tags
    ---@type string
    scope = "git",

    ---User-defined scopes or overrides
    ---For more information, please see the Scopes section
    ---@type grapple.scope_definition
    scopes = {},

    ---User-defined tag title function for Grapple windows
    ---By default, uses the resolved scope's ID
    ---@type fun(scope: grapple.resolved_scope): string?
    tag_title = nil,

    ---Additional window options for Grapple windows
    ---See :h nvim_open_win
    ---@type grapple.vim.win_opts
    win_opts = {
        relative = "editor",
        width = 0.5,
        height = 10,
        row = 0.5,
        col = 0.5,
        border = "single",
        focusable = false,
        style = "minimal",
        title = "Grapple",
        title_pos = "center",

        -- Custom: adds padding around window title
        title_padding = " ",
    },
})
```

</details>

## Usage

### Grapple API

<details>
<summary>Grapple API and Examples</summary>

In general, the Grapple API is as follows:

**Lua**: `require("grapple").{method}(opts)`
**Command**: `:Grapple [method] [opts...]`

Where `opts` in the user command are `key=value` pairs.

For example,

```vim
:Grapple tag buffer=0
```

Has the equivalent form

```lua
require("grapple").tag({ buffer = 0 })
```

#### `grapple#tag`

Create a grapple tag.

**Command**: `:Grapple tag [buffer={buffer}] [path={path}] [index={index}] [name={name}] [scope={scope}]`

**API**: `require("grapple").tag(opts)`

**`opts?`**: [`grapple.options`](#grappleoptions)

- **`buffer?`**: `integer` (default: `0`)
- **`path?`**: `string`
- **`index?`**: `integer`
- **`name?`**: `string` **not implemented**
- **`scope?`**: `string`

**Note**: only one tag can be created _per scope per file_. If a tag already exists for the given file or buffer, it will be overridden with the new tag.

<details>
<summary><b>Examples</b></summary>

```lua
-- Tag the current buffer
require("grapple").tag()

-- Tag a file by its file path
require("grapple").tag({ path = "some_file.lua" })

-- Tag the current buffer in a different scope
require("grapple").tag({ scope = "global" })
```

</details>

#### `grapple#untag`

Remove a Grapple tag.

**API**: `require("grapple").untag(opts)`

**`opts?`**: [`grapple.options`](#grappleoptions) (one of)

**Note**: Tag is removed based on one of (in order): `path`, `buffer`, `name`, `index`

<details>
<summary><b>Examples</b></summary>

```lua
-- Remove a tag on the current buffer
require("grapple").untag()

-- Remove a tag on a file
require("grapple").untag({ file_path = "{file_path}" })

-- Remove a tag on the current buffer in a different scope
require("grapple").untag({ scope = "global" })
```

</details>

#### `grapple#toggle`

Toggle a Grapple tag.

**API**: `require("grapple").toggle(opts)`

**`opts?`**: [`grapple.options`](#grappleoptions)

<details>
<summary><b>Examples</b></summary>

```lua
-- Toggle a tag on the current buffer
require("grapple").toggle()
```

</details>

#### `grapple#select`

Select a Grapple tag.

**API**: `require("grapple").select(opts)`

**`opts?`**: [`grapple.options`](#grappleoptions) (one of)

**Note**: Tag is selected based on one of (in order): `path`, `buffer`, `name`, `index`

<details>
<summary><b>Examples</b></summary>

```lua
-- Select the third tag
require("grapple").select({ index = 3 })
```

</details>

#### `grapple#exists`

**API**: `require("grapple").exists(opts)`

**`returns`**: `boolean`

**`opts?`**: [`grapple.options`](#grappleoptions) (one of)

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

**Command**: `:Grapple cycle {direction}`

**API**:

- `require("grapple").cycle(direction)`
- `require("grapple").cycle_backward()`
- `require("grapple").cycle_forward()`

**`direction`**: `"backward"` | `"forward"`

<details>
<summary><b>Examples</b></summary>

```lua
-- Cycle to the previous tagged file
require("grapple").cycle_backward()

-- Cycle to the next tagged file
require("grapple").cycle_forward()
```

</details>

#### `grapple#reset`

Clear all tags within a scope.

**Command**: `:Grapple reset [scope]`

**API**: `require("grapple").reset(scope)`

**`scope?`**: `string` (default: `settings.scope`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Reset the current scope
require("grapple").reset()

-- Reset a different scope
require("grapple").reset("global")
```

</details>

#### `grapple#quickfix`

Open the quickfix menu and populate the quickfix list with a project scope's tags.

**API**: `require("grapple").quickfix(scope)`

**`scope?`**: `string` (default: `settings.scope`)

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

### Scopes API

<details>
<summary>Scope API and Examples</summary>

#### `grapple#invalidate`

Clear any cached value for a given scope.

**API**: `require("grapple").invalidate(scope)`

**`scope?`**: `string` scope name (default: `settings.scope`)

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

</details>

## Tags

A **tag** is a persistent tag on a path or buffer. It is a means of indicating a file you want to return to. When a file is tagged, Grapple will save your cursor location so that when you jump back, your cursor is placed right where you left off. In a sense, tags are like file-level marks ([`:h mark`](https://neovim.io/doc/user/motion.html#mark-motions)).

Once a tag has been added to [scope](#scopes) for a path or buffer, it may be selected by index, cycled through, or jumped to using plugins such as [portal.nvim](https://github.com/cbochs/portal.nvim).

## Scopes

A **scope** is a means of namespacing tags to a specific project. Scopes are resolved dynamically to produce a unique identifier for a set of tags (i.e. a root directory). This identifier determines where tags are created and deleted. **Note**, different scopes may resolve the same identifier (i.e. `lsp` and `git` scopes may share the same root directory).

Scopes can also be _cached_. Each scope may define a set of `events` and/or `patterns` for an autocommand ([`:h autocmd`](https://neovim.io/doc/user/autocmd.html)), an `interval` for a timer, or to be cached indefinitely (unless invalidated explicitly). Some examples of this are the `cwd` scope which only updates on `DirChanged`.

The following scopes are made available by default:

- `global`: tags are scoped to a global namespace
- `static`: tags are scoped to neovim's initial working directory
- `cwd`: tags are scoped to the current working directory
- `lsp`: tags are scoped using the `root_dir` of the current buffer's attached LSP server, **fallback**: `static`
- `git`: tags are scoped to the current git repository, **fallback**: `static`
- `git_branch`: tags are scoped to the current git repository and branch, **fallback**: `static`

It is also possible to create your own **custom scope**. See the [Scope API]() section for more information on defining a custom scope.

<details>
<summary><b>Examples</b></summary>

```lua
-- Use a builtin scope
require("grapple").setup({
    scope = "git_branch",
})

-- Define a custom scope
require("grapple").setup({
    scope = "custom",

    scopes = {
        name = "custom",
        fallback = "cwd",
        cache = { event = "DirChanged" },
        resolver = function()
            local path = vim.env.HOME
            local id = path
            return id, path
        end
    }
})
```

</details>

## Grapple Windows

Popup windows are made available to enable easy management of tags and scopes. The opened buffer is given its own syntax (`grapple`) and file type (`grapple`) and can be modified like a regular buffer; meaning items can be selected, modified, reordered, or deleted with well-known vim motions.

<img width="1038" alt="Screenshot 2022-12-15 at 09 05 07" src="https://user-images.githubusercontent.com/2467016/207909857-98e7bc5d-8b48-4650-acb9-5993dde87a0f.png">

### Tag Window

Open a floating window containing all the tags for a given scope. The floating window can be closed with either `q` or `<esc>`. Several actions are available by default:

- **Selection** (`<cr>`): open the tag under the cursor
- **Deletion**: delete a line to delete the tag
- **Reordering**: move a line to move a tag
- **Quickfix** (`<c-q>`): send all tags to the quickfix list [`:h quickfix`](https://neovim.io/doc/user/quickfix.html)
- **Split** (`<c-v>`): open the tag under the cursor in a split

```lua
-- Set the title to "Grapple"
require("grapple").setup({
    tag_title = function(scope)
        return "Grapple"
    end
})

-- Set the title to the git root directory, with "~" substituted for $HOME
require("grapple").setup({
    tag_title = function(scope)
        return vim.fn.fnamemodify(scope.path, ":~")
    end
})
```

**API**: `require("grapple").open_tags(scope)`

**`scope?`**: `string` scope name (default: `settings.scope`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Open the tags window for the current scope
require("grapple").open_tags()

-- Open the tags window for a different scope
require("grapple").open_tags("global")
```

</details>

### Scope Window

Open a floating window containing all the loaded project scopes. The window can be closed with either `q` or `<esc>`. Some basic actions are available by default:

- **Selection** (`<cr>`): set the current scope to the one under the cursor
- **Deletion**: delete a line to reset a scope

**API**: `require("grapple").open_scopes()`

<details>
<summary><b>Examples</b></summary>

```lua
-- Open the scopes window
require("grapple").open_scopes()
```

</details>

## Persistent State

Grapple saves all [project scopes](#project-scopes) to a common directory. The default directory is named `grapple` and and lives in Neovim's `"data"` directory (see: [`:h standard-path`](https://neovim.io/doc/user/starting.html#standard-path)). Each project scope will be saved as its own individually serialized JSON blob.

By default, no project scopes are loaded on startup. When `require("grapple").setup()` is called, the default scope will be loaded. Otherwise, scopes will be loaded on demand.

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

You can use telescope to search through your tagged files instead of the built in popup menu.

Load the extension via

```lua
require("telescope").load_extension("grapple")
```

Then use this command to see the grapple tags for the project in a telescope window

```
:Telescope grapple tags
```

## Grapple Types

<details open>
<summary>Type Definitions</summary>

### `grapple.options`

Options available for most top-level tagging actions (e.g. tag, untag, select, toggle, etc).

**Type**: `table`

- **`buffer?`**: `integer` (default: `0`)
- **`path?`**: `string` file path or URI (overrides `buffer`)
- **`index?`**: `integer` tag insertion or deletion index (default: end of list)
- **`name?`**: `string` tag name
- **`scope?`**: `string` scope name (default `settings.scope`)

---

</details>

## Inspiration and Thanks

- ThePrimeagen's [harpoon](https://github.com/ThePrimeagen/harpoon)
- kwarlwang's [bufjump.nvim](https://github.com/kwkarlwang/bufjump.nvim)
- stevearc's [oil.nvim](https://github.com/stevearc/oil.nvim)
- tjdevries [vlog.nvim](https://github.com/tjdevries/vlog.nvim)
