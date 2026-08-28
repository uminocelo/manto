defmodule Manto.Plugins.TOC do
  @moduledoc """
  Table of Contents plugin for Manto.

  Scans Markdown headings (`# Heading`) and injects a nested Markdown TOC
  with anchor links at the top of the page. The TOC is inserted:

  1. At an explicit `<!-- toc -->` comment if present
  2. Before the first heading otherwise (at the very top of the content)

  ## Usage

  Enable in `manto.json`:

      { "plugins": ["toc"] }

  The plugin scans for `#`, `##`, `###`, etc. headings and builds a nested
  list of anchor links. It works at the Markdown level (before rendering).

  ### Controlling placement

  - **No `<!-- toc -->`**: TOC is auto-inserted at the top of the page
  - **With `<!-- toc -->`**: TOC replaces the comment, giving you control over position

  Example Markdown:

      # My Page

      <!-- toc -->

      ## Section One
      Content here.

      ## Section Two
      More content.

  Renders with the TOC between the title and Section One.
  """

  @behaviour Manto.Plugin

  @impl true
  def transform_markdown(markdown) do
    headings = extract_headings(markdown)

    if headings == [] do
      markdown
    else
      toc = build_toc(headings)
      insert_toc(markdown, toc)
    end
  end

  defp heading_regex do
    Regex.compile!(~S"^(#{1,6})\s+(.+)$")
  end

  defp extract_headings(markdown) do
    markdown
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.reduce([], fn {line, idx}, acc ->
      case Regex.run(heading_regex(), line, capture: :all_but_first) do
        [level, text] ->
          depth = String.length(level)
          slug = heading_slug(text)
          [{depth, text, slug, idx} | acc]

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  defp build_toc(headings) do
    min_depth = headings |> Enum.map(fn {d, _, _, _} -> d end) |> Enum.min()

    headings
    |> Enum.map(fn {depth, text, slug, _idx} ->
      indent = String.duplicate("  ", depth - min_depth)
      "#{indent}- [#{text}](##{slug})"
    end)
    |> Enum.join("\n")
  end

  defp insert_toc(markdown, toc) do
    case Regex.run(~r/<!--\s*toc\s*-->/, markdown) do
      [match] ->
        String.replace(markdown, match, toc, global: false)

      nil ->
        lines = String.split(markdown, "\n")

        case Enum.find_index(lines, fn line -> Regex.match?(heading_regex(), line) end) do
          nil ->
            Enum.join([toc, "" | lines], "\n")

          idx ->
            {before, after_lines} = Enum.split(lines, idx)
            Enum.join(before ++ [toc, ""] ++ after_lines, "\n")
        end
    end
  end

  defp heading_slug(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/u, "")
    |> String.trim()
    |> String.replace(~r/\s+/, "-")
  end
end