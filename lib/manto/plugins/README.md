# Manto Plugins

Manto's plugin pipeline lets you transform Markdown before rendering and HTML after rendering. Plugins are plain Elixir modules that implement the `Manto.Plugin` behaviour.

## How the pipeline works

```
raw Markdown
    │
    ▼
transform_markdown/1   ← plugins run in list order, each receives the previous plugin's output
    │
    ▼
MDEx renders HTML
    │
    ▼
transform_html/2       ← plugins run again in list order, each receives the previous plugin's HTML
    │
    ▼
final HTML
```

Both callbacks are **optional**. A plugin only needs to implement the hook(s) it cares about.

## The behaviour

```elixir
@callback transform_markdown(String.t()) :: String.t()
@callback transform_html(String.t(), map()) :: String.t()
```

- `transform_markdown/1` receives the raw Markdown string and returns a (possibly modified) Markdown string.
- `transform_html/2` receives the rendered HTML string and a metadata map parsed from the page's YAML front matter. It returns a (possibly modified) HTML string.

## Enabling plugins

Plugins are enabled globally via the `"plugins"` list in `manto.json`:

```json
{
  "title": "My Site",
  "plugins": ["toc", "header_image"]
}
```

Or toggle them from the **Settings** page (`/`) in the editor UI.

Plugins run in the order they appear in the list. Each plugin receives the output of the previous one.

## Built-in plugins

| Name           | Module                      | Description                                          |
| -------------- | --------------------------- | ---------------------------------------------------- |
| `toc`          | `Manto.Plugins.TOC`         | Scans headings (`#`-`######`) and injects an anchor-linked table of contents. Place it at a `<!-- toc -->` comment, or it auto-inserts before the first heading. |
| `header_image` | `Manto.Plugins.HeaderImage` | Injects a `<div class="header-image-banner">` banner from the `header_image` front matter key, before the first `<h1>`. |

## Writing a custom plugin

### 1. Create the module

Create a file under `lib/manto/plugins/` (or anywhere in your application's `lib/` tree). The module must declare `@behaviour Manto.Plugin` and implement at least one of the two callbacks.

```elixir
defmodule Manto.Plugins.Emoji do
  @moduledoc """
  Replaces shortcodes like :smile: with Unicode emoji at the Markdown level.
  """

  @behaviour Manto.Plugin

  @emoji %{
    "smile" => "😄",
    "heart" => "❤️",
    "rocket" => "🚀"
  }

  @impl true
  def transform_markdown(markdown) do
    Regex.replace(~r/:([a-z_]+):/, markdown, fn _full, name ->
      Map.get(@emoji, name, ":#{name}:")
    end)
  end
end
```

### 2. Register the plugin

Add your plugin to the `@registry` list in `lib/manto/plugin.ex`:

```elixir
@registry [
  {"toc", Manto.Plugins.TOC, "Table of Contents"},
  {"header_image", Manto.Plugins.HeaderImage, "Header Image Banner"},
  {"emoji", Manto.Plugins.Emoji, "Emoji Shortcodes"}        # ← add this line
]
```

The registry entry is a three-tuple of `{name, module, label}`:

- **`name`** — the string users put in `manto.json` and the settings page
- **`module`** — the fully-qualified Elixir module name
- **`label`** — a human-friendly label shown in the settings UI

### 3. Enable it

Add the plugin's `name` to the `"plugins"` list in `manto.json`, or check the box on the Settings page.

### 4. Write tests

Put your test in `test/manto/plugins/` following the existing plugin tests. Test each callback in isolation:

```elixir
defmodule Manto.Plugins.EmojiTest do
  use ExUnit.Case, async: true
  alias Manto.Plugins.Emoji

  test "replaces known shortcodes with emoji" do
    assert Emoji.transform_markdown("Hello :rocket:") == "Hello 🚀"
  end

  test "leaves unknown shortcodes unchanged" do
    assert Emoji.transform_markdown(":unknown:") == ":unknown:"
  end
end
```

Run the tests with:

```sh
mix test test/manto/plugins/emoji_test.exs
```

## Tips & conventions

- **One module per file.** Elixir discourages nesting multiple modules in a single file — it can cause cyclic dependencies.
- **Keep plugins pure.** A plugin is a function from string to string. Avoid side effects (no database, no network, no `Process.put/2`). This keeps them fast, testable, and safe for static builds.
- **Pattern-match on metadata.** The `metadata` map passed to `transform_html/2` contains parsed front matter. Pattern-match on the keys you care about and provide a catch-all clause that returns the HTML unchanged:

  ```elixir
  @impl true
  def transform_html(html, %{"header_image" => path}) when is_binary(path) and path != "" do
    # inject banner
  end

  def transform_html(html, _metadata), do: html
  ```

- **Order matters.** If you enable multiple plugins that touch the same content, list them in the order you want them to run. `transform_markdown` runs top-to-bottom; `transform_html` runs top-to-bottom.
- **Front matter is available.** `transform_html/2` receives a metadata map with typed values (booleans, integers, dates, lists, strings). Use it to gate behaviour on page-level metadata.
- **Return the string unchanged when there's nothing to do.** This is the expected no-op path for every plugin.
