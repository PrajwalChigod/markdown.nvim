# CLAUDE.md

Neovim plugin that renders markdown (and HTML, LaTeX, YAML frontmatter)
inside buffers using treesitter and extmarks. Requires neovim >= 0.12.

## Layout

- `plugin/renderer.lua`: entry point, version guard
- `lua/renderer/settings.lua`: all config defaults, types and schemas
- `lua/renderer/handler/`: one handler per treesitter language, runs
  queries and dispatches captures to renderers
- `lua/renderer/render/`: renderers grouped by language, each extends
  `render/base.lua` with `setup()` and `run()`
- `lua/renderer/core/colors.lua`: `Renderer*` highlight groups
- `tests/`: plenary busted specs, `tests/util.lua` holds helpers

## Commands

- `just test`: run all specs, needs `nvim-treesitter`, `mini.nvim` and
  `plenary.nvim` in the neovim data directory plus the `html`, `latex`,
  `markdown`, `markdown_inline` and `yaml` parsers
- `just check`: `selene` lint and `stylua --check`
- `just update`: regenerate README and vimdoc config sections from
  `settings.lua`

Run a single spec with:

```sh
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/html_spec.lua { minimal_init = 'tests/minimal_init.lua', sequential = true }"
```

Use `PlenaryBustedDirectory` even for a single file, `PlenaryBustedFile` runs
without the minimal init and every render spec fails.

## Conventions

- Format with `stylua` (80 columns, 4 spaces, single quotes)
- Config changes go in `settings.lua` first, then mirror them into the
  `README.md` and `doc/renderer.txt` config blocks
- New highlight groups go in `core/colors.lua` and the README highlight table
- Add specs for new rendering behavior, asserting both marks and screen
- Add user facing changes under `## Pre-release` in `CHANGELOG.md`

## Commits

- Use conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `chore:`
- Do not add `Claude-Session:` lines to commit messages or PR descriptions
