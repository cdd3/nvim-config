# Neovim configuration

Personal Neovim configuration maintained by CDD3, adapted from [jdhao/nvim-config](https://github.com/jdhao/nvim-config).

The configuration is Lua-based, uses [lazy.nvim](https://github.com/folke/lazy.nvim) for plugin management, and includes platform detection for Linux, macOS, and Windows. Platform-specific behavior and external dependencies may differ.

## Requirements

- **Neovim:** `init.lua` currently checks for version **0.12.6** and warns when the installed version differs. The check is advisory rather than a hard failure.
- **Git:** used to bootstrap lazy.nvim and download plugins.
- **Terminal:** true-color support is enabled; a Nerd Font is recommended for icon glyphs. Monaspice Nerd Font is one suitable option, but is not required by the configuration itself.
- **Optional tools:** `rg` is used for grep when available; `tmux` enables tmux-specific syntax support. Other tools may be required for particular workflows.

See [docs/README.md](docs/README.md) for the existing installation and platform setup notes. Review those instructions against the current configuration before relying on them.

## Installation

Place or clone this repository into Neovim's configuration directory, typically `~/.config/nvim` on Linux. Back up any existing configuration first.

On startup, `init.lua` loads the Lua modules and `lua/plugin_specs.lua` bootstraps lazy.nvim from its stable branch if necessary. Run `:Lazy` to inspect and manage plugins and `:checkhealth` to diagnose missing providers and dependencies.

## Configuration layout

| Path | Purpose |
| --- | --- |
| `init.lua` | Entry point, version check, module initialization |
| `lua/globals.lua` | Platform detection and global variables |
| `lua/options.lua` | Editing, display, backup, search, and terminal options |
| `lua/mappings.lua` | General keyboard mappings |
| `lua/plugin_specs.lua` | Active and commented-out plugin specifications, lazy.nvim setup |
| `lua/diagnostic-conf.lua` | Diagnostic display and quickfix mappings |
| `lua/colorschemes.lua` | Color scheme selection |
| `lua/config/` | Plugin-specific configuration modules |
| `lua/utils.lua` | Shared utility functions |

The plugin specifications are the authoritative list of enabled plugins. Commented-out entries are **not installed by this configuration** merely because they appear in the file.

## Enabled plugin features

The following are active entries in `lua/plugin_specs.lua` on the documented branch. Plugins may load only on a particular event, file type, platform, or keybinding.

| Area | Plugins | Function |
| --- | --- | --- |
| Plugin management | [lazy.nvim](https://github.com/folke/lazy.nvim) | Bootstrap, install, and load plugins |
| Syntax and structure | [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter), [vim-matchup](https://github.com/andymass/vim-matchup) | Parsing, highlighting, and matching delimiters |
| Search and navigation | [fzf-lua](https://github.com/ibhagwan/fzf-lua), [nvim-hlslens](https://github.com/kevinhwang91/nvim-hlslens), [nvim-tree](https://github.com/nvim-tree/nvim-tree.lua) | Fuzzy search, search match counts, file tree |
| Editing | [nvim-autopairs](https://github.com/windwp/nvim-autopairs), [vim-commentary](https://github.com/tpope/vim-commentary), [better-escape.vim](https://github.com/nvim-zh/better-escape.vim), [whitespace.nvim](https://github.com/jdhao/whitespace.nvim) | Pairs, comments, insert-mode escape, whitespace |
| Interface | [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim), [bufferline.nvim](https://github.com/akinsho/bufferline.nvim), [mini.icons](https://github.com/nvim-mini/mini.icons), [mini.indentscope](https://github.com/nvim-mini/mini.indentscope), [which-key.nvim](https://github.com/folke/which-key.nvim) | Status line, buffers, icons, indentation guides, mapping hints |
| Folding | [nvim-ufo](https://github.com/kevinhwang91/nvim-ufo) | Enhanced code folding |
| Git | [vim-fugitive](https://github.com/tpope/vim-fugitive), [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) | Git commands and change indicators |
| Lua development | [lazydev.nvim](https://github.com/folke/lazydev.nvim) | Lua language-server workspace support |
| Terminal and formats | [vim-oscyank](https://github.com/ojroques/vim-oscyank), [vim-tmux](https://github.com/tmux-plugins/vim-tmux), [vim-highlighturl](https://github.com/itchyny/vim-highlighturl) | OSC52 clipboard on Linux, tmux syntax, URL highlighting |
| Themes | [gruvbox-material](https://github.com/sainnhe/gruvbox-material), [kanagawa.nvim](https://github.com/rebelot/kanagawa.nvim), [modus-themes.nvim](https://github.com/miikanissi/modus-themes.nvim), [github-nvim-theme](https://github.com/projekt0n/github-nvim-theme) | Available color schemes |

`mini.icons` provides compatibility for plugins expecting `nvim-web-devicons`. Nerd Font glyph availability depends on the terminal's configured fonts.

### Features currently disabled

Several upstream or experimental integrations remain commented out in `lua/plugin_specs.lua`, including `nvim-cmp`, `blink.cmp`, `nvim-lspconfig`, `hop.nvim`, `vim-sandwich`, `UltiSnips`, `render-markdown.nvim`, `vimtex`, `nvim-notify`, `dashboard-nvim`, `firenvim`, and `asyncrun.vim`. These should not be presented as current features.

Neovim's built-in diagnostics are configured in `lua/diagnostic-conf.lua`, but the presence of diagnostic configuration alone does not imply that a language server is installed or running.

## Selected keybindings

The mappings below are defined in `lua/mappings.lua` or `lua/diagnostic-conf.lua`. Plugin-specific mappings are maintained in their respective `lua/config/` modules.

| Keys | Action |
| --- | --- |
| `<leader>w` | Save modified buffer |
| `<leader>q` | Save if modified and quit current window |
| `<leader>Q` | Quit all without saving changes |
| `<leader>ev` | Open `init.lua` in a new tab |
| `<leader>sv` | Source `init.lua` |
| `<leader><Space>` | Strip trailing whitespace |
| `<leader>cd` | Change local working directory to current file's directory |
| `<leader>y` | Yank the entire buffer |
| `<leader>cl` | Toggle cursor column |
| `<leader>cb` | Blink cursor line and column |
| `<F11>` | Toggle spell checking |
| `\\x` | Close quickfix and location lists |
| `\\d` | Delete current buffer and switch to previous |
| `\\D` | Delete other listed buffers |
| `gb` / `gB` | Navigate buffers forward / backward |
| `<A-j>` / `<A-k>` | Move line or visual selection |
| `<Space>qw` | Populate quickfix from diagnostics |
| `<Space>qb` | Populate quickfix from current buffer diagnostics |

The leader key is **comma** (`,`), set in `lua/globals.lua`. The literal Space key is also used for some mappings. Use `:verbose map {lhs}` to inspect effective mappings.

### Plugin-specific shortcuts

These mappings were checked against the corresponding active plugin configuration modules. Git shortcuts are defined in `lua/config/fugitive.lua`, but their availability depends on Fugitive actually loading (see known issues).

| Keys | Plugin | Action |
| --- | --- | --- |
| `<leader>ff` | fzf-lua | Find files |
| `<leader>fg` | fzf-lua | Live grep |
| `<leader>fh` | fzf-lua | Search help tags |
| `<leader>ft` | fzf-lua | Search tags in current buffer |
| `<leader>fb` | fzf-lua | Switch buffers |
| `<leader>fr` | fzf-lua | Search recently opened files |
| `<Space>s` | nvim-tree | Toggle file tree |
| `<Space>bp` | bufferline | Pick buffer |
| `zR` / `zM` | nvim-ufo | Open / close all folds |
| `zr` | nvim-ufo | Open folds except specified kinds |
| `<leader>K` | nvim-ufo | Preview folded lines under cursor |
| `]c` / `[c` | gitsigns | Next / previous change hunk |
| `<leader>hp` | gitsigns | Preview change hunk |
| `<leader>hb` | gitsigns | Show full line blame |
| `<leader>gs` | Fugitive | Git status |
| `<leader>gw` | Fugitive | Stage current file |
| `<leader>gc` | Fugitive | Commit |
| `<leader>gpl` / `<leader>gpu` | Fugitive | Pull / push |
| `<leader>gbn` | Fugitive | Create branch |
| `<leader>gbd` | Fugitive | Enter branch deletion command |
| `<leader>gf` | Fugitive | Enter fetch command |
| `<leader>gb` (Visual) | Fugitive | Blame selection |
| `n` / `N` / `*` / `#` | hlslens | Search navigation with match highlighting |

The file tree also has its own plugin-default mappings. Check its built-in help for those operations. This table documents explicit local mappings, not every mapping supplied by plugins.

### Other observed behavior

- Tree-sitter configuration targets Python, C++, Lua, Vimscript, JSON, TOML, YAML, JavaScript, Go, TypeScript, Markdown, shell, and Zsh, with parser installation attempted when appropriate.
- `lualine` includes Git status, Python virtual environment, attached LSP client, diagnostics, trailing-whitespace and mixed-indentation indicators.
- `lazydev.nvim` enhances Lua language-server workspace metadata but does **not** itself install or enable a language server.
- Saving Python or Lua files runs an optional formatting **check** using `black --check` or `stylua --check`, respectively, when the executable exists. This is not automatic formatting.
- Search via `fzf-lua` may depend on external search utilities; `rg` is also used as the configured grep program when present.


## Maintenance and troubleshooting

- `:Lazy`: inspect installed plugins and their loading status.
- `:Lazy sync`: synchronize plugins with the specifications.
- `:checkhealth`: inspect Neovim and plugin health.
- `:messages`: inspect startup and runtime messages.
- `:verbose map {lhs}`: identify which configuration defined a mapping.

This configuration deliberately retains some disabled plugin specifications for experimentation. Treat the active Lua configuration, rather than inherited documentation or screenshots, as the source of truth.

### Known items to verify

- **Fugitive loading:** `vim-fugitive` uses `User InGitRepo`. Both the event-triggering helper in `lua/utils.lua` and the corresponding autocommand in `lua/custom-autocmd.lua` are commented out. No active trigger was found in the reviewed modules; verify loading at runtime before relying on the Git mappings.
- **Theme selection:** `init.lua` returns before calling `color_scheme.rand_colorscheme()`, leaving that call unreachable. The theme plugins are declared, but automatic random theme selection is not active through this path.\n- **Version policy:** `init.lua` checks for exactly 0.12.6; decide whether this should remain an exact-version advisory or become a minimum-version check.
- **Platform coverage:** Linux, macOS, and Windows are detected, but plugin behavior and dependencies vary. Verify each platform before claiming identical support.
- **Keybinding scope:** the documented mappings were checked in the relevant plugin modules, but this is not an exhaustive inventory of plugin-default mappings or every optional/disabled configuration module.

## Attribution

This configuration was adapted from [Jiedong Hao's Neovim configuration](https://github.com/jdhao/nvim-config). Thanks to the original author and plugin maintainers. Refer to the repository's license and the licenses of individual plugins for applicable terms.
