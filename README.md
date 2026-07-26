# Manto

_Manto_ (Portuguese for **cloak**) is a local‑first, FOSS‑friendly Markdown CMS built with [Elixir](https://elixir-lang.org/) and [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/).  
Think of it as a lightweight cloak for your notes, docs, and ideas — simple, elegant, and entirely yours.

---

## ✨ Features (MVP)

- **Local‑first**: All content lives in plain `.md` files under `priv/content/`.
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
./manto start
```

Open http://localhost:4000/ in your browser. It redirects into the editor.

If you want the app to answer on a custom local host name, start it like this:

```bash
PHX_HOST=manto.local PORT=4000 ./manto start
```

Then add `127.0.0.1 manto.local` to your hosts file once so the name resolves locally.

After the launcher is installed into your PATH, you can use `manto start` from any terminal.

Start editing `priv/content/welcome.md` and see changes live.

To install the launcher once for your shell:

```bash
./manto install
```


## 📂 Project Structure

```bash
manto/
├── lib/
│   ├── manto/                # Core app
│   │   └── content/           # Content + parser modules
│   └── manto_web/             # Phoenix web layer
│       ├── live/              # LiveView editor & playground
│       └── controllers/       # Controllers & templates
├── priv/
│   └── content/               # Your Markdown files live here
└── README.md
```


## 🛠 Roadmap

[x] MVP: Live editor + preview

[x] Local content folder

[x] Page navigation & wiki‑style links

[x] Metadata (frontmatter)

[x] Static site generator mode

[x] Theming 

[] Publishing



> “A cloak for your words, woven in Elixir.” 