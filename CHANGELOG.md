# Change Log

## Pre-release

### Features

- render plain HTML files when `html` is added to `file_types`: page structure is
  hidden, and lists, quotes, `<pre>`, rules, headings and entities render like
  their markdown counterparts, each switchable under `html`
- render HTML `<table>` as a bordered grid using the `pipe_table` config, with
  cell text wrapped to fit the window, switch with `html.table`

### Bug Fixes

- the cursor no longer stalls on lines that are hidden completely, such as the
  head of an HTML file, when anti conceal is off: it moves on to the next visible
  line. This also steps over HTML tables and wrapped table rows instead of
  showing their source, switch with `anti_conceal.skip_hidden`. Scrolling is
  not held back by it: when scrolling carries the cursor onto hidden lines at
  the end of a buffer it stays there, so the window still reaches the end
- the title of an HTML page keeps its own line when it has one, so the cursor can
  reach the first line of the page
- HTML `<head>` titles and `<style>` / `<script>` summaries no longer show next
  to their source when `conceallevel` is below 2

## 0.1.2 (2026-10-04)

### Internal

- file formats are now described in one place, with no change in behaviour

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
