---
title: A local-first Markdown CMS
draft: false
---

# A local-first Markdown CMS

Your content lives as plain `.md` files in a folder. No database, no lock-in: just Markdown you already own. Edit it in a split-pane editor and publish how you like.

[Download](https://github.com/uminocelo/manto/releases) · [View source](https://github.com/uminocelo/manto)

<!-- toc -->

## Why Manto?

### Content is just files

Every page is a Markdown file with front matter. Back it up, diff it, search it: no database to export or migrate.

### Split-pane editor

Write in Markdown, preview rendered HTML side by side. Wiki links, tags, and GFM tables all work out of the box.

### Folders & drag-and-drop

Organize pages in nested folders. Drag pages between folders, collapse the tree, and filter by title: all in a resizable sidebar.

### Autosave & unsaved-change guard

Editor content is autosaved to `localStorage` per page. Navigate away safely, Manto warns you about unsaved changes.

### Drafts & publishing

Mark a page `draft: true` or `published: false` and it is hidden from static builds. The sidebar flags drafts at a glance.

### Plugin pipeline

Transform Markdown before rendering or HTML after. Ships with a Table-of-Contents plugin and a header-image plugin, and you can write your own via `@behaviour Manto.Plugin`.

### Dark mode

Light and dark themes driven by `data-theme` on `<html>`, persisted to `localStorage` with no flash-of-wrong-theme on load.

### Installable PWA

A service worker caches the app shell for offline use, and a web manifest makes Manto installable as a standalone app.

### Vault image serving

Drop PNG, JPG, SVG, or WebP files into your vault and reference them in Markdown. `/vault-images/*` serves them in the editor preview.

### Export a static site

`mix manto.build` renders your vault to plain HTML: folder structure, breadcrumbs, RSS, sitemap, and tag pages included.

### Themes for static builds

Ships with `default` (light) and `dark` presets, plus a theme builder in Settings for your own. Set the active theme in `manto.json`, or override it for one build with `--theme`.

### Ship a self-contained release

`mix manto.release` builds a tarball with the BEAM runtime bundled. End users run `./bin/server`: no Elixir needed, and the vault auto-seeds on first boot.

### Local-first, no auth

Runs on your own machine by default. Settings live in a small `manto.json`, not a central service.

### Phoenix LiveView

Built with Elixir and Phoenix LiveView: instant previews without a build step or a JS framework.

## Quickstart

```bash
# From source
mix setup
mix phx.server          # editor at http://localhost:4000/editor

# Or ship a release
mix manto.release
tar -xzf manto-v*.tar.gz
cd manto-v*
./bin/server
```

---

Manto is open source under the MIT License. [Fork it on GitHub](https://github.com/uminocelo/manto).