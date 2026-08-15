# Manto

_Manto_ (Portuguese for **cloak**) is a local‑first, FOSS‑friendly Markdown CMS built with [Elixir](https://elixir-lang.org/) and [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/).  
Think of it as a lightweight cloak for your notes, docs, and ideas — simple, elegant, and entirely yours.

---

## ✨ Features (MVP)

- **Local‑first**: All content lives in plain `.md` files in a configurable vault (default `priv/content/`).
- **Live editor**: Split‑pane editor with real‑time Markdown preview.
- **MDEx powered**: Fast, extensible Markdown rendering with syntax highlighting, emoji shortcodes, and sanitization.
- **Git‑friendly**: Content is just files — version them however you like.
- **No lock‑in**: Clone, run, and hack locally. No external services required.

---

## 🚀 Quickstart

Clone and run locally:

```bash
git clone https://github.com/uminocelo/manto
cd manto
mix setup
mix phx.server
```

Open http://localhost:4000 in your browser. The **settings page** lets you point Manto at your vault — the folder holding your Markdown files — and customize your site (`title`, `description`, `base URL`). Settings are saved to `manto.json` in the project root.

Then head to http://localhost:4000/editor to start writing. Every save writes straight to the `.md` files in your vault, so you can edit them by hand or with any editor too. The sidebar groups pages by folder, and you can create or rename a page inside a folder by typing a path like `docs/guide` in the "New page" box.

> Fresh clone? `mix setup` seeds `priv/content/welcome.md` for you (or run `mix manto.init` manually). `priv/content/*` is gitignored — your pages stay yours.

### Building the static site

```bash
mix manto.build                 # renders every published page to priv/static_site/
mix manto.build --output dist   # or to any output directory
```

Pages can live in nested folders — `docs/guide.md` becomes `docs/guide.html`, keeping the folder structure in the output. Every page gets a breadcrumb trail back to the home page, and each folder gets an auto‑generated `index.html` listing its pages and subfolders (a page named `<folder>/index` overrides the auto‑generated one). Wiki‑links, stylesheets, and tag links all resolve correctly from any depth.


## 📂 Project Structure

```bash
manto/
├── lib/
│   ├── manto/                # Core app
│   │   ├── content/           # Content + parser modules
│   │   └── site.ex            # Site/vault settings (manto.json)
│   └── manto_web/             # Phoenix web layer
│       ├── live/              # Settings page & Markdown editor
│       └── controllers/       # Controllers & templates
├── priv/
│   └── content/               # Your Markdown files live here (default vault)
├── manto.json                 # Vault path & site settings (created on save)
└── README.md
```


## 🛠 Roadmap

[x] MVP: Live editor + preview

[x] Local content folder

[x] Page navigation & wiki‑style links

[x] Metadata (frontmatter)

[x] Static site generator mode

[x] Theming 

[x] Publishing (drafts hidden from static builds, published/updated dates)



> “A cloak for your words, woven in Elixir.” 