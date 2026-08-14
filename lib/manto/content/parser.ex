defmodule Manto.Content.Parser do
  @moduledoc """
  Wraps MDEx rendering and normalizes results into plain strings.
  """

  alias MDEx

  @mdex_opts [
    extension: [front_matter_delimiter: "---", table: true, shortcodes: true],
    syntax_highlight: [formatter: {:html_inline, theme: "onedark"}]
  ]
  @wiki_link_regex ~r/\[\[([^\]]+)\]\]/

  @doc """
  Render Markdown into safe HTML string.

  Wiki-style `[[Page Name]]` links are rewritten to `\#{link_prefix}Slug\#{link_suffix}`
  (defaults to editor links, e.g. `/editor/Slug`; the static build uses `Slug.html` instead).
  Front matter (if present) is stripped from the output.

  Always returns a binary, never a tuple.
  """
  @spec render_html(String.t(), keyword()) :: String.t()
  def render_html(markdown, opts \\ []) when is_binary(markdown) do
    markdown
    |> rewrite_wiki_links(opts)
    |> MDEx.to_html(@mdex_opts)
    |> case do
      {:ok, html} -> html
      _ -> ""
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

  defp rewrite_wiki_links(markdown, opts) do
    prefix = Keyword.get(opts, :link_prefix, "/editor/")
    suffix = Keyword.get(opts, :link_suffix, "")

    Regex.replace(@wiki_link_regex, markdown, fn _, name ->
      slug = String.replace(String.trim(name), " ", "-")
      "[#{name}](#{prefix}#{slug}#{suffix})"
    end)
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
