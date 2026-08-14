defmodule Manto.Content.ParserTest do
  use ExUnit.Case, async: true
  alias Manto.Content.Parser

  test "metadata/1 reads front matter into a map" do
    md = "---\ntitle: Hello\n---\n\n# Body"
    assert Parser.metadata(md) == %{"title" => "Hello"}
  end

  test "metadata/1 types booleans and integers" do
    md = "---\ndraft: true\npublished: false\npriority: 3\n---"
    assert Parser.metadata(md) == %{"draft" => true, "published" => false, "priority" => 3}
  end

  test "metadata/1 parses comma-separated and YAML block lists" do
    md = "---\ntags: a, b, c\nauthors:\n  - uminocelo\n  - alucarddz\n---"

    assert Parser.metadata(md) == %{
             "tags" => ["a", "b", "c"],
             "authors" => ["uminocelo", "alucarddz"]
           }
  end

  test "metadata/1 parses ISO dates and datetimes" do
    md = """
    ---
    date: 2026-08-13
    created: 2026-08-13T10:30:00Z
    ---
    """

    metadata = Parser.metadata(md)
    assert metadata["date"] == ~D[2026-08-13]
    assert metadata["created"] == ~U[2026-08-13 10:30:00Z]
  end

  test "metadata/1 strips matching quotes and keeps malformed values as strings" do
    md = ~S(---
title: "Hello, World"
draft: maybe
date: not-a-date
---
)

    assert Parser.metadata(md) == %{
             "title" => "Hello, World",
             "draft" => "maybe",
             "date" => "not-a-date"
           }
  end

  test "metadata/1 returns an empty map without front matter" do
    assert Parser.metadata("# Just a heading") == %{}
  end

  test "draft?/1 flags draft and unpublished metadata" do
    assert Parser.draft?(%{"draft" => true})
    assert Parser.draft?(%{"published" => false})
    refute Parser.draft?(%{"draft" => false})
    refute Parser.draft?(%{"published" => true})
    refute Parser.draft?(%{})
  end

  test "render_html/1 strips front matter and rewrites wiki links" do
    md = "---\ntitle: Hello\n---\n\nSee [[Other Page]]."
    html = Parser.render_html(md)

    refute html =~ "title: Hello"
    assert html =~ ~s(<a href="/editor/Other-Page">Other Page</a>)
  end

  test "render_html/2 accepts a custom link prefix/suffix for wiki links" do
    html = Parser.render_html("See [[Other Page]].", link_prefix: "", link_suffix: ".html")
    assert html =~ ~s(<a href="Other-Page.html">Other Page</a>)
  end

  test "render_html/1 renders GFM tables" do
    md = "| Month | Savings |\n| --- | --- |\n| January | $250 |\n"
    html = Parser.render_html(md)

    assert html =~ "<table>"
    assert html =~ "<th>Month</th>"
    assert html =~ "<td>$250</td>"
  end

  test "render_html/1 renders emoji shortcodes" do
    assert Parser.render_html(":smile: :fire:") =~ "😄 🔥"
    assert Parser.render_html(":smile:") =~ "😄"
  end

  test "render_html/1 syntax-highlights fenced code blocks" do
    html = Parser.render_html("```elixir\nEnum.map([1, 2], &(&1 * 2))\n```")

    assert html =~ ~s(<code class="language-elixir")
    assert html =~ ~s(<pre class="athl")
  end
end
