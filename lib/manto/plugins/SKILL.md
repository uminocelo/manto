---
name: manto-plugin
description: Create a Manto content plugin. Use when the user wants to write, generate, scaffold, or scaffold a Manto plugin, implement the Manto.Plugin behaviour, or add a transform_markdown/transform_html plugin to the Manto pipeline.
---

# Manto Plugin Generator

This skill creates a new **Manto plugin** — an Elixir module implementing the `Manto.Plugin` behaviour that transforms Markdown before rendering and/or HTML after rendering.

## What you will produce

For a plugin named `<name>`, you will create **three files** and edit **one**:

1. `lib/manto/plugins/<name>.ex` — the plugin module
2. `test/manto/plugins/<name>_test.exs` — unit tests for both callbacks
3. (Edit) `lib/manto/plugin.ex` — register the plugin in the `@registry` list

Optionally enable the plugin in `manto.json` or tell the user to toggle it on the Settings page (`/`).

## Before you start

Read these files to understand the behaviour, conventions, and existing patterns:

- `lib/manto/plugin.ex` — the behaviour definition, registry, and pipeline runners
- `lib/manto/plugins/toc.ex` — reference plugin that implements `transform_markdown/1`
- `lib/manto/plugins/header_image.ex` — reference plugin that implements `transform_html/2`
- `test/manto/plugins/toc_test.exs`
- `test/manto/plugins/header_image_test.exs`
- `lib/manto/plugins/README.md` — the full author guide

## Step 1 — Gather the plugin spec

Ask the user (or infer from the request) for:

| Field          | Required | Example                                          |
| -------------- | -------- | ------------------------------------------------ |
| **name**       | yes      | `emoji`, `word_count`, `external_links`          |
| **label**      | yes      | `"Emoji Shortcodes"`, `"External Link Icons"`    |
| **hook**       | yes      | `transform_markdown`, `transform_html`, or both  |
| **description**| yes      | What the plugin does, in one sentence            |
| **config keys**| no       | Front matter keys the plugin reads (e.g. `header_image`, `tags`) |
| **options**    | no       | Any user-tunable options and their defaults       |

If the user didn't specify a hook, infer it from what the plugin does:

- Operates on Markdown source text (regex on `#`, lists, raw text) → `transform_markdown/1`
- Operates on rendered HTML (DOM, tags, attributes) → `transform_html/2`
- Needs both (e.g. extract in MD, inject in HTML) → implement both

## Step 2 — Generate the module

Create `lib/manto/plugins/<name>.ex`. Follow these conventions exactly:

```elixir
defmodule Manto.Plugins.<CamelName> do
  @moduledoc """
  <Label> plugin for Manto.

  <Description of what it does and when it runs in the pipeline.>

  ## Usage

  Enable in `manto.json`:

      { "plugins": ["<name>"] }

  <Any front matter keys or options the user needs to set, with examples.>
  """

  @behaviour Manto.Plugin

  @impl true
  def transform_markdown(markdown) do
    # implementation
  end

  # OR / AND

  @impl true
  def transform_html(html, metadata) do
    # implementation
  end
end
```

### Conventions

- **One module per file.** Never nest multiple modules in the same file.
- **`@impl true`** on every callback.
- **Pure functions.** No side effects, no `Process.put/2`, no database, no network. Plugins are string-in, string-out.
- **Catch-all clause.** If the plugin gates on metadata, provide a catch-all function clause that returns the input unchanged:

  ```elixir
  @impl true
  def transform_html(html, %{"some_key" => value}) when is_binary(value) and value != "" do
    # do the work
  end

  def transform_html(html, _metadata), do: html
  ```

- **No `String.to_atom/1`** on user input.
- **Predicate names end in `?`.** Don't prefix with `is_`.
- **Access front matter via the `metadata` map** (second arg to `transform_html/2`). It contains typed values parsed from YAML front matter.

## Step 3 — Generate tests

Create `test/manto/plugins/<name>_test.exs`. Cover:

1. The happy path — the plugin does its thing when its conditions are met
2. The no-op path — input returned unchanged when conditions aren't met
3. Edge cases — empty input, missing metadata, special characters, unicode
4. Ordering — if the plugin injects content, assert its position relative to existing elements

Follow the pattern in `test/manto/plugins/toc_test.exs` and `test/manto/plugins/header_image_test.exs`:

```elixir
defmodule Manto.Plugins.<CamelName>Test do
  use ExUnit.Case, async: true
  alias Manto.Plugins.<CamelName>

  test "<does the thing> when <condition>" do
    input = "<fixture>"
    result = <CamelName>.transform_markdown(input)   # or transform_html(input, metadata)

    assert result =~ "<expected substring>"
    # assert ordering with :binary.match/2 if position matters
  end

  test "returns input unchanged when <no-op condition>" do
    input = "<fixture>"
    assert <CamelName>.transform_markdown(input) == input
  end
end
```

Run the tests:

```sh
mix test test/manto/plugins/<name>_test.exs
```

## Step 4 — Register the plugin

Edit `lib/manto/plugin.ex`. Add a three-tuple to the `@registry` list:

```elixir
@registry [
  {"toc", Manto.Plugins.TOC, "Table of Contents"},
  {"header_image", Manto.Plugins.HeaderImage, "Header Image Banner"},
  {"<name>", Manto.Plugins.<CamelName>, "<Label>"}   # ← add
]
```

The tuple is `{name (string), module (atom), label (string)}`.

## Step 5 — Verify

Run, in order:

```sh
mix test test/manto/plugins/<name>_test.exs   # plugin tests pass
mix test test/manto/plugin_test.exs          # registry / pipeline tests pass
mix test test/manto/plugins/                  # all plugin tests pass
```

Then run the full precommit gate to ensure nothing else broke:

```sh
mix precommit
```

This runs `compile --warning-as-errors`, `deps.unlock --unused`, `format`, and `test`.

## Step 6 — Enable (optional)

If the user wants the plugin active immediately, add its `name` to the `"plugins"` list in `manto.json`:

```json
{
  "plugins": ["toc", "<name>"]
}
```

Or tell the user to check the box on the **Settings** page at `/`.

## Checklist

- [ ] `lib/manto/plugins/<name>.ex` created with `@behaviour Manto.Plugin`
- [ ] At least one of `transform_markdown/1` or `transform_html/2` implemented with `@impl true`
- [ ] Catch-all clause returns input unchanged when conditions aren't met
- [ ] `@moduledoc` explains usage with a `manto.json` example
- [ ] `test/manto/plugins/<name>_test.exs` covers happy path, no-op path, and edge cases
- [ ] `lib/manto/plugin.ex` `@registry` updated with `{name, module, label}`
- [ ] `mix test test/manto/plugins/<name>_test.exs` passes
- [ ] `mix test test/manto/plugin_test.exs` passes
- [ ] `mix precommit` passes
