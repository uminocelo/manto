defmodule Manto.Content.Parser do
  @moduledoc """
  Wraps MDEx rendering and normalizes results into plain strings.
  """

  alias MDEx

  @mdex_opts [
    extension: [
      front_matter_delimiter: "---",
      table: true,
      shortcodes: true,
      strikethrough: true,
      tasklist: true,
      autolink: true,
      footnotes: true,
      header_id_prefix: "",
      alerts: true,
      block_directive: true,
      wikilinks_title_after_pipe: true
    ],
    render: [unsafe: true],
    syntax_highlight: [
      engine: :lumis,
      opts: [
        formatter:
          {:html_multi_themes,
           themes: [light: "github_light", dark: "onedark"], default_theme: "light-dark()"}
      ]
    ],
    sanitize: [
      add_tags: ["input"],
      add_tag_attributes: %{
        "a" => ["data-wikilink"],
        "input" => ["disabled", "checked", "type"],
        "pre" => ["style"],
        "code" => ["style", "translate", "tabindex"],
        "span" => ["style"],
        "div" => ["data-line"]
      },
      add_allowed_classes: %{
        "div" => [
          "markdown-alert",
          "markdown-alert-note",
          "markdown-alert-tip",
          "markdown-alert-warning",
          "markdown-alert-important",
          "markdown-alert-caution",
          "info",
          "warning",
          "tip",
          "danger",
          "l-line"
        ],
        "p" => ["markdown-alert-title"],
        "pre" => ["lumis", "lumis-themes", "dark", "light"],
        "code" => ["language-elixir"]
      }
    ]
  ]

  @doc """
  Render Markdown into safe HTML string.

  Wiki-style `[[Page Name]]` links are rewritten to `\#{link_prefix}Slug\#{link_suffix}`
  (defaults to editor links, e.g. `/editor/Slug`; the static build uses `Slug.html` instead).
  Front matter (if present) is stripped from the output.

  Always returns a binary, never a tuple.
  """
  @spec render_html(String.t(), keyword()) :: String.t()
  def render_html(markdown, opts \\ []) when is_binary(markdown) do
    metadata = Keyword.get(opts, :metadata, %{})

    markdown
    |> Manto.Plugin.run_markdown()
    |> MDEx.to_html(@mdex_opts)
    |> case do
      {:ok, html} ->
        html |> Manto.Plugin.run_html(metadata) |> rewrite_wikilink_hrefs(opts)

      _ ->
        ""
    end
  end

  @doc """
  Extract front matter as a string-keyed map, e.g. `---\\ntitle: Hi\\n---` -> %{"title" => "Hi"}.

  Values are typed: `true`/`false` become booleans, bare integers become
  integers, ISO 8601 dates/datetimes become `Date`/`DateTime` structs,
  comma-separated values and YAML `- item` blocks become lists, and matching
  surrounding quotes are stripped. Everything else stays a string. Returns an
  empty map when there's no front matter.
  """
  @spec metadata(String.t()) :: map()
  def metadata(markdown) when is_binary(markdown) do
    with {:ok, doc} <- MDEx.parse_document(markdown, @mdex_opts),
         %MDEx.FrontMatter{literal: literal} <-
           Enum.find(doc.nodes, &match?(%MDEx.FrontMatter{}, &1)) do
      parse_front_matter(literal)
    else
      _ -> %{}
    end
  end

  @doc """
  Whether a metadata map describes a draft: either `draft: true` or
  `published: false`. Pages without either key are treated as published.
  """
  @spec draft?(map()) :: boolean()
  def draft?(metadata) when is_map(metadata) do
    Map.get(metadata, "draft", false) == true or Map.get(metadata, "published", true) == false
  end

  defp rewrite_wikilink_hrefs(html, opts) do
    prefix = Keyword.get(opts, :link_prefix, "/editor/")
    suffix = Keyword.get(opts, :link_suffix, "")

    Regex.replace(~r/<a href="([^"]+)" data-wikilink="true"/, html, fn _, href ->
      slug = href |> URI.decode() |> slugify()
      ~s(<a href="#{prefix}#{slug}#{suffix}" data-wikilink="true")
    end)
  end

  @doc """
  Extract the slugified targets of all `[[wiki links]]` in the markdown, e.g.
  `[[Other Page]]` becomes `"Other-Page"`. Duplicates are removed. Use this to
  cross-check links against existing pages.
  """
  @spec wiki_link_targets(String.t()) :: [String.t()]
  def wiki_link_targets(markdown) when is_binary(markdown) do
    Regex.scan(~r/\[\[([^\]]+)\]\]/, markdown)
    |> Enum.map(fn [_, name] -> name |> String.split("|") |> hd() |> slugify() end)
    |> Enum.uniq()
  end

  defp slugify(name) do
    name
    |> String.trim()
    |> String.replace(" ", "-")
  end

  defp parse_front_matter(literal) do
    literal
    |> String.split("\n")
    |> Enum.reduce({%{}, nil}, &add_front_matter_line/2)
    |> elem(0)
  end

  defp add_front_matter_line(line, {acc, current_key}) do
    trimmed = String.trim(line)

    # YAML block list: "- item" lines append to the value of the current key
    if Regex.match?(~r/^-\s+/, trimmed) and not is_nil(current_key) do
      item = trimmed |> String.trim_leading("-") |> String.trim()
      existing = Map.get(acc, current_key, [])
      items = if is_list(existing), do: existing, else: []
      {Map.put(acc, current_key, items ++ [item]), current_key}
    else
      case parse_front_matter_line(line) do
        {key, value} -> {Map.put(acc, key, value), key}
        :skip -> {acc, current_key}
      end
    end
  end

  defp parse_front_matter_line(line) do
    with [key, value] <- String.split(line, ":", parts: 2),
         key = String.trim(key),
         true <- key != "" do
      {key, parse_value(String.trim(value))}
    else
      _ -> :skip
    end
  end

  defp parse_value(value) do
    cond do
      value == "true" -> true
      value == "false" -> false
      value =~ ~r/^-?\d+$/ -> String.to_integer(value)
      is_quoted?(value) -> String.slice(value, 1, String.length(value) - 2)
      value == "" -> value
      String.contains?(value, ",") -> parse_list(value)
      true -> parse_date_or_string(value)
    end
  end

  defp parse_list(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_date_or_string(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> parse_datetime_or_string(value)
    end
  end

  defp parse_datetime_or_string(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _ -> value
    end
  end

  defp is_quoted?(value) do
    (String.starts_with?(value, "\"") and String.ends_with?(value, "\"")) or
      (String.starts_with?(value, "'") and String.ends_with?(value, "'"))
  end
end
