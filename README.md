# Grapple.nvim

<img width="1080" alt="image" src="https://github.com/cbochs/grapple.nvim/assets/2467016/1b350ddf-78f2-4457-899b-5b3cdeade01e">

_Theme: [kanagawa](https://github.com/rebelot/kanagawa.nvim)_

<details>
<summary>Showcase</summary>

![grapple_showcase](https://user-images.githubusercontent.com/2467016/207667062-13883515-fd21-4d40-be87-656665de3d0e.gif)

**Note**: this showcase is slightly outdated, but aside from the command name changes, it still represents how Grapple works.

</details>

## Introduction

Grapple is a plugin that aims to provide immediate navigation to important files (and their last known cursor location). See the [quickstart](#quickstart) section to get started.

## Features

- **Persistent** cursor tracking for tagged files
- **Scoped** file tagging for immediate navigation
- **Popup** windows to manage tags and scopes as regular text
- **Integration** with [portal.nvim](https://github.com/cbochs/portal.nvim) for additional jump options

## Requirements

- [Neovim >= 0.9](https://github.com/neovim/neovim/releases/tag/v0.9.0)

## Quickstart

- [Install](#installation) Grapple.nvim using your preferred package manager
- Add a keybind to `tag`, `untag`, or `toggle` a path. For example,

```lua
vim.keymap.set("n", "<leader>m", "<cmd>Grapple toggle<cr>")
vim.keymap.set("n", "<leader>M", "<cmd>Grapple open_tags<cr>")
```

**Next steps**

- Check out the default [settings](#settings)
- View your tags with `:Grapple open_tags`
- Choose a scope with `:Grapple open_scopes`
- Manage your loaded scopes with `:Grapple open_loaded`
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
    ---@type grapple.scope_definition[]
    scopes = {},

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
        relative = "editor",
        width = 0.5,
        height = 10,
        row = 0.5,
        col = 0.5,
        border = "single",
        focusable = false,
        style = "minimal",
        title_pos = "center",

        -- Custom: "{{ title }}" will use the tag_title or scope_title
        title = "{{ title }}",

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

Where `opts` in the user command is a list of `value` arguments `key=value` keyword arguments. For example,

```vim
:Grapple cycle forward scope=cwd
```

Has the equivalent form

```lua
require("grapple").cycle("forward", { scope = "cwd" })
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

**Note**: Tag is selected based on one of (in order): `index`, `name`, `path`, `buffer`

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

#### `grapple#cycle`

Cycle through and select from the available tagged files in a scoped tag list.

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

#### `grapple#reset`

Clear all tags for a scope.

**Command**: `:Grapple reset [scope={scope}] [id={id}]`

**API**: `require("grapple").reset(opts)`

**`opts?`**: `table`

- **`scope?`**: `string` scope name
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

#### `grapple#define_scope`

Create a user-defined scope.

**API**: `require("grapple").define_scope(definition)`

**`definition`**: [`grapple.scope_definition`](#grapplescope_definition)

<details>
<summary><b>Examples</b></summary>

```lua
-- Define a scope during setup
require("grapple").setup({
    scope = "home_dir",

    scopes = {
        {
            name = "home_dir",
            desc = "Home directory",
            cache = { debounce = 250 }
            resolver = function()
                local path = vim.loop.cwd()
                local id = path
                return id, path, nil
            end
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

#### `grapple#use_scope`

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

#### `grapple#clear_cache`

Clear any cached value for a given scope.

**API**: `require("grapple").clear_cache(scope)`

**`scope?`**: `string` scope name (default: `settings.scope`)

<details>
<summary><b>Examples</b></summary>

```lua
-- Clear the cached value (if any) for the "git" scope
require("grapple").clear_cache("git")
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
- `lsp`: tags are scoped using the `root_dir` of the current buffer's attached LSP server, **fallback**: `static`
- `git`: tags are scoped to the current git repository, **fallback**: `static`
- `git_branch`: tags are scoped to the current git repository and branch, **fallback**: `static`

It is also possible to create your own **custom scope**. See the [Scope API](#scopes-api) section for more information.

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

Popup windows are made available to enable easy management of tags and scopes. The opened buffer is given its own syntax (`grapple`) and file type (`grapple`) and can be modified like a regular buffer; meaning items can be selected, modified, reordered, or deleted with well-known vim motions. The floating window can be closed with either `q` or `<esc>`.

<img width="1080" alt="image" src="https://github.com/cbochs/grapple.nvim/assets/2467016/19aa1902-3bbb-4eab-9707-a1fa053fea09">

### Tags Window

Open a floating window with all the tags for a given scope. This buffer is modifiable. Several actions are available by default:

- **Selection** (`<cr>`): select the tag under the cursor
- **Split (horizontal)** (`-`): select the tag under the cursor (`split`)
- **Split (vertical)** (`|`): select the tag under the cursor (`vsplit`)
- **Deletion**: delete a line to delete the tag
- **Reordering**: move a line to move a tag
- **Quickfix** (`<c-q>`): send all tags to the quickfix list ([`:h quickfix`](https://neovim.io/doc/user/quickfix.html))

Note, the title used by the tags window may be adjusted in the [settings](#settings).

```lua
-- Set title relative to the users home directory
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

### Scopes Window

Open a floating window with all defined scopes. This buffer is not modifiable. Some basic actions are available by default:

- **Selection** (`<cr>`): set the current scope to the one under the cursor

**API**: `require("grapple").open_scopes()`

<details>
<summary><b>Examples</b></summary>

```lua
-- Open the scopes window
require("grapple").open_scopes()
```

</details>

### Loaded Scopes Window

Open a floating window with all loaded scopes. This buffer is not modifiable. Some basic actions are available by default:

- **Selection** (`<cr>`): open the tags window for the loaded scope under the cursor
- **Deletion (`x`)**: reset the tags for the loaded scope under the cursor

**API**: `require("grapple").open_loaded()`

<details>
<summary><b>Examples</b></summary>

```lua
-- Open the scopes window
require("grapple").open_loaded()
```

</details>

## Persistent State

Grapple saves all scopes to a common directory. The default directory is named `grapple` and lives in Neovim's `"data"` directory ([`:h standard-path`](https://neovim.io/doc/user/starting.html#standard-path)). Each scope will be saved as its own individually serialized JSON blob.

By default, no scopes are loaded on startup. When `require("grapple").setup()` is called, the default scope will be loaded. Otherwise, scopes will be loaded on demand.

## Integrations

### Telescope

You can use telescope to search through your tagged files instead of the built in popup windows.

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
- **`path`**: `string` file path or URI (overrides `buffer`)
- **`name`**: `string` tag name
- **`index`**: `integer` tag insertion or deletion index (default: end of list)
- **`scope`**: `string` scope name (default `settings.scope`)

### `grapple.cache.options`

Options available for defining how a scope should be cached.

**Type**: `table`

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
- kwarlwang's [bufjump.nvim](https://github.com/kwkarlwang/bufjump.nvim)
- stevearc's [oil.nvim](https://github.com/stevearc/oil.nvim)
- tjdevries [vlog.nvim](https://github.com/tjdevries/vlog.nvim)

<!-- panvimdoc-ignore-end -->
