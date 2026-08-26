defmodule Manto.Plugin do
  @moduledoc """
  Behaviour and pipeline runner for Manto content plugins.

  Each plugin is an Elixir module that implements one or both callbacks:

    - `transform_markdown/1` — modify raw Markdown before MDEx rendering
    - `transform_html/2` — modify rendered HTML after MDEx rendering

  Plugins are enabled globally via the `"plugins"` list in `manto.json`
  (e.g. `["toc", "header_image"]`). Enabled plugin modules are called in
  list order; each receives the output of the previous one.

  Both callbacks are optional — a plugin only needs to implement the hook(s)
  it cares about.
  """

  @doc "Transform raw Markdown before rendering. Return the (possibly modified) Markdown string."
  @callback transform_markdown(String.t()) :: String.t()

  @doc "Transform rendered HTML after MDEx. Receives the HTML and a metadata map from front matter. Return the (possibly modified) HTML string."
  @callback transform_html(String.t(), map()) :: String.t()

  @optional_callbacks transform_markdown: 1, transform_html: 2

  # ── Registry ──────────────────────────────────────────────────────────

  @registry [
    {"toc", Manto.Plugins.TOC, "Table of Contents"},
    {"header_image", Manto.Plugins.HeaderImage, "Header Image Banner"}
  ]

  @doc """
  Return all known plugins as `{name, module, label}` tuples.
  """
  @spec available_plugins() :: [{String.t(), module(), String.t()}]
  def available_plugins, do: @registry

  # ── Resolution ────────────────────────────────────────────────────────

  @doc """
  Return the list of plugin modules currently enabled in site config,
  in the order they appear in the `"plugins"` list.
  """
  @spec enabled_plugins() :: [module()]
  def enabled_plugins do
    enabled_names = Manto.Site.config()["plugins"] || []

    @registry
    |> Enum.filter(fn {name, _, _} -> name in enabled_names end)
    |> Enum.map(fn {_, module, _} -> module end)
  end

  # ── Pipeline runners ──────────────────────────────────────────────────

  @doc """
  Run all enabled plugins' `transform_markdown/1` callback in order.
  Each plugin receives the output of the previous one. Plugins that do not
  implement `transform_markdown/1` are skipped.
  """
  @spec run_markdown(String.t()) :: String.t()
  def run_markdown(body) when is_binary(body) do
    Enum.reduce(enabled_plugins(), body, fn mod, acc ->
      if function_exported?(mod, :transform_markdown, 1) do
        mod.transform_markdown(acc)
      else
        acc
      end
    end)
  end

  @doc """
  Run all enabled plugins' `transform_html/2` callback in order.
  Each plugin receives the rendered HTML and a metadata map. Plugins that do
  not implement `transform_html/2` are skipped.
  """
  @spec run_html(String.t(), map()) :: String.t()
  def run_html(html, metadata \\ %{}) when is_binary(html) and is_map(metadata) do
    Enum.reduce(enabled_plugins(), html, fn mod, acc ->
      if function_exported?(mod, :transform_html, 2) do
        mod.transform_html(acc, metadata)
      else
        acc
      end
    end)
  end
end
