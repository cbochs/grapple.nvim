# Grapple.nvim

<!-- panvimdoc-ignore-start -->

<img width="1080" alt="image" src="https://github.com/cbochs/grapple.nvim/assets/2467016/1b350ddf-78f2-4457-899b-5b3cdeade01e">

Theme: [kanagawa](https://github.com/rebelot/kanagawa.nvim)

<details>
<summary>Showcase</summary>

![grapple-showcase](https://github.com/cbochs/grapple.nvim/assets/2467016/61cca5ae-26af-411f-904f-3eb7735a50c4)

</details>

<!-- panvimdoc-ignore-end -->

## Introduction

Grapple is a plugin that aims to provide immediate navigation to important files (and their last known cursor location). See the [quickstart](#quickstart) section to get started.

## Motivation

Grapple began as a combined plugin of both [Harpoon](https://github.com/ThePrimeagen/harpoon) and [Portal](https://github.com/cbochs/portal.nvim). While Portal was split into its own plugin later, Grapple remained with the goal of improving it's file navigation model. However, Grapple aimed to improve over existing plugins (like Harpoon) in four main areas:

1. **User setup**: provide a _frictionless_ experience for first-time setup, configuration, and usage
1. **User command**: make the entire [Grapple API](#grapple-api) _easily accessible_ (via Lua or user command)
1. **User experience**: provide a set of [windows](#grapple-windows) for managing tags and scopes
1. **User-controlled tag scopes**: let the user _choose_ how their [tags](#tags) are grouped in a project

In fact, at this point, Grapple can be used as an [almost perfect](#example-setups) drop-in replacement and do [even more](#usage).

## Features

- **Persistent** tags on file paths to track and restore cursor location
- **Scoped** tags for fine-grained, per-project tagging (i.e. git branch)
- **Rich** well-defined [Grapple](#grapple-api) and [Scope](#scope-api) APIs
- **Toggleable** windows to manage tags and scopes as a regular vim buffer
- **Integration** with [telescope.nvim](#telescope)
- **Integration** with [portal.nvim](https://github.com/cbochs/portal.nvim) for additional jump options

## Requirements

- [Neovim >= 0.9](https://github.com/neovim/neovim/releases/tag/v0.9.0)
- [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) (optional)

## Quickstart

- [Install](#installation) Grapple.nvim using your preferred package manager
- Add a keybind to `tag`, `untag`, or `toggle` a path. For example,

```lua
-- Lua
vim.keymap.set("n", "<leader>m", require("grapple").toggle)
vim.keymap.set("n", "<leader>M", require("grapple").toggle_tags)

-- User command
vim.keymap.set("n", "<leader>1", "<cmd>Grapple select index=1<cr>")
```

**Next steps**

- Coming from Harpoon? Check out the [example setups](#example-setups)
- Check out the default [settings](#settings)
- View your [tags](#tags-window) with `:Grapple toggle_tags`
- Choose a [scope](#scopes-window) with `:Grapple toggle_scopes`
- Manage your [loaded scopes](#loaded-scopes-window) with `:Grapple toggle_loaded`
- Add a [statusline component](#statusline)
- Explore the [Grapple](#grapple-api) and [Scope](#scope-api) APIs

## Installation

<details>
<summary>lazy.nvim</summary>

```lua
{
    "cbochs/grapple.nvim",
    dependencies = {
        { "nvim-tree/nvim-web-devicons", lazy = true }
    },
}
```

</details>

<details>
<summary>packer</summary>

```lua
use {
    "cbochs/grapple.nvim",
    requires = { "nvim-tree/nvim-web-devicons" }
}
```

</details>

<details>
<summary>vim-plug</summary>

```vim
Plug "nvim-tree/nvim-web-devicons"
Plug "cbochs/grapple.nvim"
```

</details>

## Example Setups

Note, these examples assume you are using the [lazy.nvim](https://github.com/folke/lazy.nvim) package manager.

<details>
<summary>Recommended</summary>

```lua
{
    "cbochs/grapple.nvim",
    opts = {
        scope = "git", -- also try out "git_branch"
    },
    event = { "BufReadPost", "BufNewFile" },
    cmd = "Grapple",
    keys = {
        { "<leader>m", "<cmd>Grapple toggle<cr>", desc = "Grapple toggle tag" },
        { "<leader>k", "<cmd>Grapple toggle_tags<cr>", desc = "Grapple toggle tags" },
        { "<leader>K", "<cmd>Grapple toggle_scopes<cr>", desc = "Grapple toggle scopes" },
        { "<leader>j", "<cmd>Grapple cycle forward<cr>", desc = "Grapple cycle forward" },
        { "<leader>J", "<cmd>Grapple cycle backward<cr>", desc = "Grapple cycle backward" },
        { "<leader>1", "<cmd>Grapple select index=1<cr>", desc = "Grapple select 1" },
        { "<leader>2", "<cmd>Grapple select index=2<cr>", desc = "Grapple select 2" },
        { "<leader>3", "<cmd>Grapple select index=3<cr>", desc = "Grapple select 3" },
        { "<leader>4", "<cmd>Grapple select index=3<cr>", desc = "Grapple select 4" },
    },
},
```

</details>

<details>
<summary>Harpoon</summary>

Example configuration similar to [harpoon.nvim](https://github.com/ThePrimeagen/harpoon) (based off of this [example setup](https://github.com/ThePrimeagen/harpoon/tree/harpoon2?tab=readme-ov-file#basic-setup)).

```lua
{
    "cbochs/grapple.nvim",
    opts = {
        scope = "git", -- also try out "git_branch"
        icons = false, -- setting to "true" requires "nvim-web-devicons"
        status = false,
    },
    keys = {
        { "<leader>a", "<cmd>Grapple toggle<cr>", desc = "Tag a file" },
        { "<c-e>", "<cmd>Grapple toggle_tags<cr>", desc = "Toggle tags menu" },

        { "<c-h>", "<cmd>Grapple select index=1<cr>", desc = "Select first tag" },
        { "<c-t>", "<cmd>Grapple select index=2<cr>", desc = "Select second tag" },
        { "<c-n>", "<cmd>Grapple select index=3<cr>", desc = "Select third tag" },
        { "<c-s>", "<cmd>Grapple select index=4<cr>", desc = "Select fourth tag" },

        { "<c-s-p>", "<cmd>Grapple cycle backward<cr>", desc = "Go to previous tag" },
        { "<c-s-n>", "<cmd>Grapple cycle forward<cr>", desc = "Go to next tag" },
    },
},
```

</details>

<details>
<summary>Arrow</summary>

Example configuration similar to [arrow.nvim](https://github.com/otavioschwanck/arrow.nvim/tree/master).

```lua
{
    "cbochs/grapple.nvim",
    dependencies = {
        { "nvim-tree/nvim-web-devicons" }
    },
    opts = {
        scope = "git_branch",
        icons = true,
        quick_select = "123456789",
    },
    keys = {
        { ";", "<cmd>Grapple toggle_tags<cr>", desc = "Toggle tags menu" },

        { "<c-s>", "<cmd>Grapple toggle<cr>", desc = "Toggle tag" },
        { "H", "<cmd>Grapple cycle forward<cr>", desc = "Go to next tag" },
        { "L", "<cmd>Grapple cycle backward<cr>", desc = "Go to previous tag" },
    },
},
```

</details>

## Settings

The following are the default settings for Grapple. **Setup is not required**, but settings may be overridden by passing them as table arguments to the `Grapple.setup` function.

<details>
<summary>Default Settings</summary>

```lua
require("grapple").setup({
    ---Grapple save location
    ---@type string
    save_path = vim.fs.joinpath(vim.fn.stdpath("data"), "grapple"),

    ---Default scope to use when managing Grapple tags
    ---For more information, please see the Scopes section
    ---@type string
    scope = "git",

    ---User-defined scopes or overrides
    ---For more information, please see the Scope API section
    ---@type grapple.scope_definition[]
    scopes = {},

    ---Show icons next to tags or scopes in Grapple windows
    ---Requires "nvim-tree/nvim-web-devicons"
    ---@type boolean
    icons = true,

    ---Highlight the current selection in Grapple windows
    ---Also, indicates when a tag path does not exist
    ---@type boolean
    status = true,

    ---Position a tag's name should be shown in Grapple windows
    ---@type "start" | "end"
    name_pos = "end",

    ---How a tag's path should be rendered in Grapple windows
    ---  "relative": show tag path relative to the scope's resolved path
    ---  "basename": show tag path basename and directory hint
    ---@type "basename" | "relative"
    style = "relative",

    ---A string of characters used for quick selecting in Grapple windows
    ---An empty string or nil will disable quick select
    ---@type string | nil
    quick_select = "123456789",

    ---User-defined tags title function for Grapple windows
    ---By default, uses the resolved scope's ID
    ---@type fun(scope: grapple.resolved_scope): string?
    tag_title = nil,

    ---User-defined scopes title function for Grapple windows
    ---By default, renders "Grapple Scopes"
    ---@type fun(): string?
    scope_title = nil,

    ---User-defined loaded scopes title function for Grapple windows
    ---By default, renders "Grapple Loaded Scopes"
    ---@type fun(): string?
    loaded_title = nil,

    ---Additional window options for Grapple windows
    ---See :h nvim_open_win
    ---@type grapple.vim.win_opts
    win_opts = {
        -- Can be fractional
        width = 80,
        height = 12,
        row = 0.5,
        col = 0.5,

        relative = "editor",
        border = "single",
        focusable = false,
        style = "minimal",
        title_pos = "center",

        -- Custom: fallback title for Grapple windows
        title = "Grapple",

        -- Custom: adds padding around window title
        title_padding = " ",
    },
})
```

</details>

## Usage

In general, the API is as follows:

**Lua**: `require("grapple").{method}(...)`
<br>
**Command**: `:Grapple [method] [opts...]`

Where `opts` in the user command is a list of `value` arguments and `key=value` keyword arguments. For example,

```vim
:Grapple cycle forward scope=cwd
```

Has the equivalent form

```lua
require("grapple").cycle("forward", { scope = "cwd" })
```

### Grapple API

<details>
<summary>Grapple API and Examples</summary>

#### `Grapple.tag`

Create a grapple tag.

**Command**: `:Grapple tag [buffer={buffer}] [path={path}] [index={index}] [name={name}] [scope={scope}]`

**API**: `require("grapple").tag(opts)`

**`opts?`**: [`grapple.options`](#grappleoptions)

- **`buffer?`**: `integer` (default: `0`)
- **`path?`**: `string`
- **`index?`**: `integer`
- **`name?`**: `string`
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

-- Tag the file path under the cursor
require("grapple").tag({ path = "<cfile>" })
```

</details>

#### `Grapple.untag`

Remove a Grapple tag.

**API**: `require("grapple").untag(opts)`

**`opts?`**: [`grapple.options`](#grappleoptions) (one of)

**Note**: Tag is removed based on one of (in order): `index`, `name`, `path`, `buffer`

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

#### `Grapple.toggle`

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

#### `Grapple.select`

Select a Grapple tag.

**API**: `require("grapple").select(opts)`

**`opts?`**: [`grapple.options`](#grappleoptions) (one of)

**Note**: Tag is selected based on one of (in order): `index`, `name`, `path`, `buffer`

<details>
<summary><b>Examples</b></summary>

```lua
-- Select the third tag
require("grapple").select({ index = 3 })
```

</details>

#### `Grapple.exists`

Return if a tag exists. Used for statusline components

**API**: `require("grapple").exists(opts)`

**`returns`**: `boolean`

**`opts?`**: [`grapple.options`](#grappleoptions) (one of)

**Note**: Tag is searched based on one of (in order): `index`, `name`, `path`, `buffer`

<details>
<summary><b>Examples</b></summary>

```lua
-- Check whether the current buffer is tagged or not
require("grapple").exists()

-- Check for a tag in a different scope
require("grapple").exists({ scope = "global" })
```

</details>

#### `Grapple.cycle`

Cycle through and select the next or previous available tag for a given scope.

**Command**: `:Grapple cycle {direction} [opts...]`

**API**:

- `require("grapple").cycle(direction, opts)`
- `require("grapple").cycle_backward(opts)`
- `require("grapple").cycle_forward(opts)`

**`direction`**: `"backward"` | `"forward"`
**`opts?`**: [`grapple.options`](#grappleoptions) (one of)

**Note**: Starting tag is searched based on one of (in order): `index`, `name`, `path`, `buffer`

<details>
<summary><b>Examples</b></summary>

```lua
-- Cycle to the previous tagged file
require("grapple").cycle_backward()

-- Cycle to the next tagged file
require("grapple").cycle_forward()
```

</details>

#### `Grapple.reset`

Clear all tags for a scope.

**Command**: `:Grapple reset [scope={scope}] [id={id}]`

**API**: `require("grapple").reset(opts)`

**`opts?`**: `table`

- **`scope?`**: `string` scope name (default: `settings.scope`)
- **`id?`**: `string` the ID of a resolved scope

<details>
<summary><b>Examples</b></summary>

```lua
-- Reset the current scope
require("grapple").reset()

-- Reset a scope (dynamic)
require("grapple").reset({ scope = "git" })

-- Reset a specific resolved scope ID
require("grapple").reset({ id = "~/git" })
```

</details>

#### `Grapple.quickfix`

Open the quickfix window populated with paths from a given scope

**API**: `require("grapple").quickfix(opts)`

**`opts?`**: `table`

- **`scope?`**: `string` scope name (default: `settings.scope`)
- **`id?`**: `string` the ID of a resolved scope

<details>
<summary><b>Examples</b></summary>

```lua
-- Open the quickfix window for the current scope
require("grapple").quickfix()

-- Open the quickfix window for a specified scope
require("grapple").quickfix("global")
```

</details>

</details>

### Scope API

<details>
<summary>Scopes API and Examples</summary>

#### `Grapple.define_scope`

Create a user-defined scope.

**API**: `require("grapple").define_scope(definition)`

**`definition`**: [`grapple.scope_definition`](#grapplescope_definition)

<details>
<summary><b>Examples</b></summary>

For more examples, see [settings.lua](./lua/grapple/settings.lua)

```lua
-- Define a scope during setup
require("grapple").setup({
    scope = "cwd_branch",

    scopes = {
        {
            name = "cwd_branch",
            desc = "Current working directory and git branch",
            fallback = "cwd",
            cache = {
                event = { "BufEnter", "FocusGained" },
                debounce = 1000, -- ms
            },
            resolver = function()
                local git_files = vim.fs.find(".git", {
                    upward = true,
                    stop = vim.loop.os_homedir(),
                })

                if #git_files == 0 then
                    return
                end

                local root = vim.loop.cwd()

                local result = vim.fn.system({ "git", "symbolic-ref", "--short", "HEAD" })
                local branch = vim.trim(string.gsub(result, "\n", ""))

                local id = string.format("%s:%s", root, branch)
                local path = root

                return id, path
            end,
        }
    }
})

-- Define a scope outside of setup
require("grapple").define_scope({
    name = "projects",
    desc = "Project directory"
    fallback = "cwd",
    cache = { event = "DirChanged" },
    resolver = function()
        local projects_dir = vim.fs.find("projects", {
            upwards = true,
            stop = vim.loop.os_homedir()
        })

        if #projects_dir == 0 then
            return nil, nil, "Not in projects dir"
        end

        local path = projects_dir[1]
        local id = path
        return id, path, nil
    end
})

-- Use the scope
require("grapple").use_scope("projects")
```

</details>

#### `Grapple.use_scope`

Change the currently selected scope.

**API**: `require("grapple").use_scope(scope)`

**`scope`**: `string` scope name

<details>
<summary><b>Examples</b></summary>

```lua
-- Clear the cached value (if any) for the "git" scope
require("grapple").use_scope("git_branch")
```

</details>

#### `Grapple.clear_cache`

Clear any cached value for a given scope.

**API**: `require("grapple").clear_cache(scope)`

**`scope?`**: `string` scope name (default: `settings.scope`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Clear the cached value for the initial working directory scope
require("grapple").clear_cache("static")
```

</details>

</details>

## Tags

A **tag** is a persistent tag on a path or buffer. It is a means of indicating a file you want to return to. When a file is tagged, Grapple will save your cursor location so that when you jump back, your cursor is placed right where you left off. In a sense, tags are like file-level marks ([`:h mark`](https://neovim.io/doc/user/motion.html#mark-motions)).

Once a tag has been added to a [scope](#scopes), it may be selected by index, cycled through, or jumped to using plugins such as [portal.nvim](https://github.com/cbochs/portal.nvim).

## Scopes

A **scope** is a means of namespacing tags to a specific project. Scopes are resolved dynamically to produce a unique identifier for a set of tags (i.e. a root directory). This identifier determines where tags are created and deleted. **Note**, different scopes may resolve the same identifier (i.e. `lsp` and `git` scopes may share the same root directory).

Scopes can also be _cached_. Each scope may define a set of `events` and/or `patterns` for an autocommand ([`:h autocmd`](https://neovim.io/doc/user/autocmd.html)), an `interval` for a timer, or to be cached indefinitely (unless invalidated explicitly). Some examples of this are the `cwd` scope which only updates on `DirChanged`.

The following scopes are made available by default:

- `global`: tags are scoped to a global namespace
- `static`: tags are scoped to neovim's initial working directory
- `cwd`: tags are scoped to the current working directory
- `lsp`: tags are scoped to the root directory of the current buffer's attached LSP server, **fallback**: `cwd`
- `git`: tags are scoped to the current git repository, **fallback**: `cwd`
- `git_branch`: tags are scoped to the current git directory **and** git branch, **fallback**: `cwd`

It is also possible to create your own **custom scope**. See the [Scope API](#scope-api) for more information.

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

Popup windows are made available to enable easy management of tags and scopes. The opened buffer is given its own syntax (`grapple`) and file type (`grapple`) and can be modified like a regular buffer; meaning items can be selected, modified, reordered, or deleted with well-known vim motions. The floating window can be toggled or closed with either `q` or `<esc>`.

### Tags Window

<img width="1080" alt="image" src="https://github.com/cbochs/grapple.nvim/assets/2467016/e1fda612-c4f2-4202-9264-c8c6aee68795">

Open a floating window with all the tags for a given scope. This buffer is modifiable. Several actions are available by default:

- **Selection** (`<cr>`): select the tag under the cursor
- **Split (horizontal)** (`<c-s>`): select the tag under the cursor (`split`)
- **Split (vertical)** (`|`): select the tag under the cursor (`vsplit`)
- **Quick select** (default: `1-9`): select the tag at a given index
- **Deletion**: delete a line to delete the tag
- **Reordering**: move a line to move a tag
- **Renaming** (`R`): rename the tag under the cursor
- **Quickfix** (`<c-q>`): send all tags to the quickfix list ([`:h quickfix`](https://neovim.io/doc/user/quickfix.html))
- **Go up** (`-`): navigate up to the [scopes window](#scopes-window)

**API**:

- `require("grapple").open_tags(opts)`
- `require("grapple").toggle_tags(opts)`

**`opts?`**: `table`

- **`scope?`**: `string` scope name
- **`id?`**: `string` the ID of a resolved scope

<details>
<summary><b>Examples</b></summary>

```lua
-- Open the tags window for the current scope
require("grapple").open_tags()

-- Open the tags window for a different scope
require("grapple").open_tags("global")
```

</details>

### Scopes Window

<img width="1080" alt="image" src="https://github.com/cbochs/grapple.nvim/assets/2467016/6af61cfa-3765-4dbf-a117-d599791e9a74">

Open a floating window with all defined scopes. This buffer is not modifiable. Some basic actions are available by default:

- **Selection** (`<cr>`): open the [tags window](#tags-window) for the scope under the cursor
- **Quick select** (default: `1-9`): open the tags window for the scope at a given index
- **Change** (`<s-cr>`): change the current scope to the one under the cursor
- **Go up** (`-`): navigate across to the [loaded scopes window](#loaded-scopes-window)

**API**:

- `require("grapple").open_scopes()`
- `require("grapple").toggle_scopes()`

<details>
<summary><b>Examples</b></summary>

```lua
-- Open the scopes window
require("grapple").open_scopes()
```

</details>

### Loaded Scopes Window

<img width="1080" alt="image" src="https://github.com/cbochs/grapple.nvim/assets/2467016/8b91222f-cf5e-43b9-9286-56379a6a80f0">

Open a floating window with all loaded scopes. This buffer is not modifiable. Some basic actions are available by default:

- **Selection** (`<cr>`): open the [tags window](#tags-window) for the loaded scope under the cursor
- **Quick select** (default: `1-9`): open tags window for the loaded scope at a given index
- **Deletion (`x`)**: reset the tags for the loaded scope under the cursor
- **Go up** (`-`): navigate across to the [scopes window](#scopes-window)

**API**:

- `require("grapple").open_loaded()`
- `require("grapple").toggle_loaded()`

<details>
<summary><b>Examples</b></summary>

```lua
-- Open the scopes window
require("grapple").open_loaded()
```

</details>

### Window Highlights

| Highlight        | Default Link      | Style      | Used in                         |
| ---------------- | ----------------- | ---------- | ------------------------------- |
| `GrappleBold`    | N/A               | `gui=bold` | Scopes window for scope names   |
| `GrappleHint`    | `Comment`         | N/A        | Tags window for directory hints |
| `GrappleName`    | `DiagnosticHint`  | N/A        | Tags window for tag name        |
| `GrappleNoExist` | `DiagnosticError` | N/A        | Tags window for tag status      |
| `GrappleCurrent` | `SpecialChar`     | `gui=bold` | All windows for current status  |

## Persistent State

Grapple saves all scopes to a common directory. The default directory is named `grapple` and lives in Neovim's `"data"` directory ([`:h standard-path`](https://neovim.io/doc/user/starting.html#standard-path)). Each scope will be saved as its own individually serialized JSON blob.

By default, no scopes are loaded on startup. When `require("grapple").setup()` is called, the default scope will be loaded. Otherwise, scopes will be loaded on demand.

## Integrations

### Telescope

You can use [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) to search through your tagged files instead of the built in popup windows.

Load the extension with

```lua
require("telescope").load_extension("grapple")
```

Then use this command to see the grapple tags for the project in a telescope window

```vim
:Telescope grapple tags
```

### Statusline

A statusline component can be easily added to show whether a buffer is tagged.

**[lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) statusline**

```lua
require("lualine").setup({
    sections = {
        lualine_b = {
            {
                require("grapple").statusline,
                cond = require("grapple").exists
            }
        }
    }
})
```

## Grapple Types

<details open>
<summary>Type Definitions</summary>

### `grapple.options`

Options available for most top-level tagging actions (e.g. tag, untag, select, toggle, etc).

**Type**: `table`

- **`buffer`**: `integer` (default: `0`)
- **`path`**: `string` file path or `<cfile>` (overrides `buffer`)
- **`name`**: `string` tag name
- **`index`**: `integer` tag insertion or deletion index (default: end of list)
- **`scope`**: `string` scope name (default `settings.scope`)

### `grapple.cache.options`

Options available for defining how a scope should be cached. Using the value of `true` will indicate a value should be cached indefinitely and is equivalent to providing an empty set of options (`{}`).

**Type**: `table` | `boolean`

- **`event?`**: `string` | `string[]` autocmd event ([`:h autocmd`](https://neovim.io/doc/user/autocmd.html))
- **`pattern?`**: `string` autocmd pattern, useful for `User` events
- **`interval?`**: `integer` timer interval
- **`debounce?`**: `integer` debounce interval

### `grapple.scope_definition`

Used for defining new scopes.

**Type**: `table`

- **`name`**: `string` scope name
- **`desc`**: `string` scope description
- **`resolver`**: [`grapple.scope_resolver`](#grapplescope_resolver)
- **`fallback?`**: `string` fallback scope name
- **`cache?`**: [`grapple.cache.options`](#grapplecacheoptions) | `boolean`

### `grapple.scope_resolver`

Used for defining new scopes. Must return a tuple of `(id, path, err)`. If successful, an `id` must be provided with an optional absolute path `path`. If unsuccessful, `id` must be `nil` with an optional `err` explaining what when wrong.

**Type**: `function`

**Returns**: `string? id, string? path, string? err`

### `grapple.resolved_scope`

Result from observing a scope at a point in time.

**Type** `class`

- **`name`**: `string` scope name
- **`id`**: `string` resolved scope ID
- **`path`**: `string` | `nil` resolved scope path
- **`:tags()`**: returns all tags for the given ID

</details>

<!-- panvimdoc-ignore-start -->

### Contributors

Thanks to these wonderful people for their contributions!

<a href="https://github.com/cbochs/grapple.nvim/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=cbochs/grapple.nvim" />
</a>

## Inspiration and Thanks

- ThePrimeagen's [harpoon](https://github.com/ThePrimeagen/harpoon)
- stevearc's [oil.nvim](https://github.com/stevearc/oil.nvim)

<!-- panvimdoc-ignore-end -->
