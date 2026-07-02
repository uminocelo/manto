defmodule Manto.Content.ParserTest do
  use ExUnit.Case, async: true
  alias Manto.Content.Parser

  test "metadata/1 reads front matter into a map" do
    md = "---\ntitle: Hello\ntags: a, b\n---\n\n# Body"
    assert Parser.metadata(md) == %{"title" => "Hello", "tags" => "a, b"}
  end

  test "metadata/1 returns an empty map without front matter" do
    assert Parser.metadata("# Just a heading") == %{}
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
end
