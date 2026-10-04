# Change Log

## Pre-release

## 0.1.1 (2026-10-04)

### Bug Fixes

- buffers whose root language is not markdown now render when `nested = false`

## 0.1.0 (2026-10-03)

First release of this fork, based on
[render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) 8.14.0.

### Breaking Changes

- renamed to `renderer.nvim`: module `require('renderer')`, command `:Renderer`,
  highlight groups `Renderer*`, config global `vim.g.renderer_config`,
  health check `:checkhealth renderer`
- require neovim >= 0.12, support for older versions is dropped along with the compatibility layer

### Features

- render common HTML tags (bold, italic, headings, links, images, etc.) in HTML blocks and inline within paragraphs, including `align="center"` and `<center>`
