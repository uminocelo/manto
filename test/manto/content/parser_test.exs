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
    assert html =~ ~s(href="/editor/Other-Page")
  end

  test "render_html/2 accepts a custom link prefix/suffix for wiki links" do
    html = Parser.render_html("See [[Other Page]].", link_prefix: "", link_suffix: ".html")
    assert html =~ ~s(href="Other-Page.html")
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

    assert html =~ ~s(lumis lumis-themes)
    assert html =~ ~s(light-dark)
  end

  test "wiki_link_targets/1 extracts slugified, deduplicated targets" do
    md = "See [[Other Page]], [[Other Page]] again, and [[Missing]]."

    assert Parser.wiki_link_targets(md) == ["Other-Page", "Missing"]
  end

  test "wiki_link_targets/1 returns an empty list without wiki links" do
    assert Parser.wiki_link_targets("No links here.") == []
  end

  test "wiki_link_targets/1 extracts page name before pipe" do
    assert Parser.wiki_link_targets("[[Page|Display]] and [[Other|Show]]") == ["Page", "Other"]
  end

  test "render_html/1 renders pipe syntax in wiki links" do
    html = Parser.render_html("[[Other Page|Click here]]")
    assert html =~ ~s(href="/editor/Other-Page")
    assert html =~ "Click here"
  end

  test "render_html/1 does not rewrite wiki links inside code blocks" do
    html = Parser.render_html("`[[not a link]]`")
    assert html =~ "<code>"
    assert html =~ "[[not a link]]"
    refute html =~ ~s(href="/editor/not-a-link")
  end

  # ── GFM extensions ─────────────────────────────────────────────────────

  test "render_html/1 renders strikethrough text" do
    assert Parser.render_html("~~strikethrough~~") =~ "<del>strikethrough</del>"
  end

  test "render_html/1 renders task list items" do
    html = Parser.render_html("- [ ] todo\n- [x] done")
    assert html =~ ~s(<input type="checkbox" disabled="">)
    assert html =~ ~s(<input type="checkbox" checked="" disabled="">)
  end

  test "render_html/1 auto-links bare URLs" do
    html = Parser.render_html("https://example.com")
    assert html =~ ~s(href="https://example.com")
    assert html =~ "https://example.com"
  end

  test "render_html/1 renders footnotes" do
    md = "Some text[^1]\n\n[^1]: The footnote content."
    html = Parser.render_html(md)

    assert html =~ ~s(href="#fn-1")
    assert html =~ ~s(href="#fnref-1")
    assert html =~ "The footnote content."
  end

  test "render_html/1 auto-generates heading anchor links" do
    html = Parser.render_html("## My Section")
    assert html =~ ~s(<h2>My Section<a href="#my-section")
  end

  # ── Sanitization ───────────────────────────────────────────────────────

  test "render_html/1 sanitizes javascript: links" do
    html = Parser.render_html("[click](javascript:alert(1))")
    refute html =~ "javascript:"
  end

  test "render_html/1 sanitizes raw script tags" do
    html = Parser.render_html("<script>alert(1)</script>text")
    refute html =~ "<script>"
    assert html =~ "text"
  end

  test "render_html/1 strips event handler attributes" do
    html = Parser.render_html(~s|<img src=x onerror="alert(1)">|)
    refute html =~ "onerror"
  end

  test "render_html/1 preserves normal content through sanitization" do
    md =
      "# Hello\n\nParagraph with **bold** and [a link](https://example.com).\n\n- list item\n\n```\ncode\n```\n"

    html = Parser.render_html(md)

    assert html =~ "<h1>Hello"
    assert html =~ "<strong>bold</strong>"
    assert html =~ ~s(href="https://example.com")
    assert html =~ "<li>list item</li>"
    assert html =~ "<code"
  end

  # ── Admonitions ────────────────────────────────────────────────────────

  test "render_html/1 renders GitHub-style alerts with class and title" do
    html = Parser.render_html("> [!NOTE]\n> A note.\n")
    assert html =~ ~s(class="markdown-alert markdown-alert-note")
    assert html =~ ~s(class="markdown-alert-title")
    assert html =~ "Note"
    assert html =~ "A note."
  end

  test "render_html/1 renders block directive containers" do
    html = Parser.render_html(":::info\nInfo content.\n:::\n")
    assert html =~ ~s(class="info")
    assert html =~ "Info content"
  end

  test "render_html/1 renders multiple alert types" do
    md = "> [!WARNING]\n> Warning text.\n\n> [!TIP]\n> A tip.\n"
    html = Parser.render_html(md)

    assert html =~ "markdown-alert-warning"
    assert html =~ "markdown-alert-tip"
    assert html =~ "Warning text."
    assert html =~ "A tip."
  end
end
