# Manto

_Manto_ (Portuguese for **cloak**) is a local‑first, FOSS‑friendly Markdown CMS built with [Elixir](https://elixir-lang.org/) and [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/).  
Think of it as a lightweight cloak for your notes, docs, and ideas — simple, elegant, and entirely yours.

---

## ✨ Features

- **Local‑first**: All content lives in plain `.md` files in a configurable vault (default `priv/content/`).
- **Live editor**: Split‑pane editor with real‑time Markdown preview, draft status badges, and folder navigation.
- **MDEx powered**: Fast, extensible Markdown rendering with syntax highlighting, emoji shortcodes, and sanitization.
- **Git‑friendly**: Content is just files — version them however you like.
- **No lock‑in**: Clone, run, and hack locally. No external services required.
- **Plugin system**: Extend the rendering pipeline — built-in plugins for table of contents and header images, plus a simple behaviour for writing your own.
- **Fabric themes**: A design‑token theme engine with a visual theme builder, built‑in presets (light/dark), custom CSS support, and per‑build theme selection.
- **Draft workflow**: Mark pages as drafts via front matter (`draft: true` or `published: false`); drafts are excluded from the static site and shown with a badge in the editor.
- **Tag taxonomy**: Add `tags: [elixir, phoenix]` to front matter and the static build generates tag archive pages.
- **RSS & Sitemap**: Auto‑generated `rss.xml` and `sitemap.xml` on every static build.
- **Wiki‑links**: `[[Page Name]]` syntax links to other pages, with broken‑link detection in the build output.
- **Vault images**: Images stored in your vault are served via `/vault-images/` and path‑rewritten in static builds.
- **Dark/Light/System toggle**: Three‑way theme toggle for the UI chrome, persisted to `localStorage`.
- **PWA ready**: Service worker with cache‑first strategy for the app shell, plus a Web App Manifest for installable desktop/mobile apps.

---

## 🚀 Quickstart

Clone and run locally:

```bash
git clone https://github.com/uminocelo/manto
cd manto
mix setup
mix phx.server
```

Open http://localhost:4000 in your browser. The **settings page** is your control centre — configure the vault path, customize site metadata (`title`, `description`, `base URL`), toggle plugins, and build themes. Settings are saved to `manto.json` in the project root.

Then head to http://localhost:4000/editor to start writing. Every save writes straight to the `.md` files in your vault, so you can edit them by hand or with any editor too. The sidebar groups pages by folder, highlights drafts, and you can create or rename a page inside a folder by typing a path like `docs/guide` in the "New page" box.

> Fresh clone? `mix setup` seeds `priv/content/welcome.md` for you (or run `mix manto.init` manually). `priv/content/*` is gitignored — your pages stay yours.

### Settings page

The settings page at `/` is where you configure Manto:

- **Vault path**: Point Manto at any folder of Markdown files on your machine.
- **Site info**: Set the site title, description, and base URL (used for RSS/sitemap).
- **Plugins**: Toggle built‑in plugins (TOC, Header Image) on and off.
- **Theme builder**: A visual editor for Fabric themes — pick colors following the 60/30/10 rule, choose fonts, set page width and content radius, add custom CSS, and save, duplicate, or delete themes. The active theme is used by both the editor preview and the static build.

### Building the static site

```bash
mix manto.build                              # renders every published page to priv/static_site/
mix manto.build --output dist                # or to any output directory
mix manto.build --theme dark                 # pick a theme (built-in or custom)
mix manto.build --theme my-custom-theme      # or use a saved custom theme
```

Pages can live in nested folders — `docs/guide.md` becomes `docs/guide.html`, keeping the folder structure in the output. Every page gets a breadcrumb trail back to the home page, and each folder gets an auto‑generated `index.html` listing its pages and subfolders (a page named `<folder>/index` overrides the auto‑generated one). Wiki‑links, stylesheets, and tag links all resolve correctly from any depth. Drafts are automatically excluded, and the build reports broken wiki‑links, tag pages, RSS feed, and sitemap.

### Distributing Manto

```bash
mix manto.release                # builds a self-contained tarball
mix manto.release --version 0.2.0
```

Builds a self‑contained release (bundled BEAM runtime — end users don't need Elixir installed) into `dist/manto-vX.Y.Z.tar.gz`. After extracting, users just run `./bin/server` and open http://localhost:4000; an empty vault is seeded with `welcome.md` on first boot. Optional env vars: `PORT`, `PHX_HOST`, `SECRET_KEY_BASE`.

---

## 🔌 Plugin System

Manto's rendering pipeline is extensible via plugins. Each plugin implements the `Manto.Plugin` behaviour with one or both callbacks:

- `transform_markdown/1` — receives the raw Markdown string, returns transformed Markdown (runs before MDEx rendering).
- `transform_html/1` — receives the rendered HTML string, returns transformed HTML (runs after MDEx rendering).

Plugins run in order, each receiving the output of the previous one. Enable and disable them from the Settings page, or directly in `manto.json` under the `"plugins"` key.

### Built-in plugins

| Plugin | Description |
|--------|-------------|
| **TOC** | Auto‑generates a table of contents from page headings. Place `<!-- toc -->` in your Markdown where the TOC should appear. |
| **Header Image** | Injects a banner `<div>` at the top of the page from the `header_image` front‑matter key. |

### Writing a custom plugin

```elixir
defmodule MyApp.Plugin do
  @moduledoc """
  A custom plugin that adds a footer to every page.
  """
  use Manto.Plugin,
    name: :my_plugin,
    label: "My Plugin"

  @impl true
  def transform_html(html) do
    html <> "<footer>Built with Manto</footer>"
  end
end
```

Register it in `Manto.Plugin`'s `@registry` and it will appear in the Settings page. See `lib/manto/plugins/README.md` for the full authoring guide.

---

## 🎨 Fabric Themes

Fabric is a design‑token theme engine baked into Manto. Themes are defined by a set of tokens and compiled into a CSS variable block plus a full page template.

### Design tokens

| Token | Description |
|-------|-------------|
| **Primary** | 60% of the page — dominant color (text + background) |
| **Secondary** | 30% — supporting color (text + background) |
| **Accent** | 10% — highlights, links, call‑to‑action (text + background) |
| **Font heading** | CSS font‑family for headings (`h1`–`h6`) |
| **Font body** | CSS font‑family for body text |
| **Font code** | CSS font‑family for `<code>` and `<pre>` |
| **Page width** | Max‑width of the content area (e.g. `42rem`) |
| **Content radius** | Border‑radius for cards and content blocks |
| **Custom CSS** | URL or local file path for additional stylesheets |

### Built-in presets

- **Default** — light theme with a clean, readable palette.
- **Dark** — dark theme for low‑light reading.

### Theme builder

The Settings page includes a full visual theme builder with color pickers, font inputs, width/radius sliders, and a custom CSS field. You can create new themes, duplicate existing ones, and delete them. The active theme is used by the editor preview and the static build (`mix manto.build --theme <name>`).

### Custom CSS

The `custom_css` field accepts either a URL (linked as a `<link>` stylesheet in the build output) or a local file path (copied into the build output directory).

---

## 📂 Project Structure

```bash
manto/
├── lib/
│   ├── manto/                    # Core app
│   │   ├── content/               # Content + parser modules
│   │   ├── fabric/                # Theme engine (tokens, presets, CSS, page template)
│   │   ├── plugin.ex              # Plugin behaviour and registry
│   │   ├── plugins/               # Built-in plugins (toc, header_image)
│   │   └── site.ex                # Site/vault settings (manto.json)
│   ├── manto_web/                 # Phoenix web layer
│   │   ├── live/                  # Settings page, theme builder & Markdown editor
│   │   └── controllers/           # Controllers, layouts, vault images plug
│   └── mix/tasks/                 # Mix tasks (manto.build, manto.release, manto.init)
├── priv/
│   ├── content/                   # Your Markdown files live here (default vault)
│   └── static/                    # PWA manifest, service worker, icons
├── manto.json                     # Vault path, site settings, plugins, themes
└── README.md
```

> “A cloak for your words, woven in Elixir.”