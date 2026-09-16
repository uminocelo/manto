defmodule Manto.Content.ParserPluginsTest do
  use ExUnit.Case, async: false
  alias Manto.Content.Parser

  setup do
    path =
      Path.join(
        System.tmp_dir!(),
        "manto-parser-plugin-#{System.unique_integer([:positive])}.json"
      )

    on_exit(fn -> File.rm(path) end)

    previous = Application.get_env(:manto, :config_path)
    Application.put_env(:manto, :config_path, path)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:manto, :config_path, previous),
        else: Application.delete_env(:manto, :config_path)
    end)

    :ok
  end

  test "render_html with TOC plugin enabled — TOC appears in output HTML" do
    Manto.Site.save(%{"plugins" => ["toc"]})

    md = """
    # My Page

    ## Section One
    Content.
    """

    html = Parser.render_html(md)

    assert html =~ "<ul>"
    assert html =~ ~s(href="#section-one")
    assert html =~ ~s(<h1>My Page<a href="#my-page">)
    assert html =~ ~s(<h2>Section One<a href="#section-one">)
  end

  test "render_html with header_image plugin enabled and metadata — banner div in output" do
    Manto.Site.save(%{"plugins" => ["header_image"]})

    md = """
    # My Page
    Content here.
    """

    metadata = %{"header_image" => "/images/hero.png"}
    html = Parser.render_html(md, metadata: metadata)

    assert html =~ ~s(class="header-image-banner")
    assert html =~ ~s(src="/images/hero.png")
  end

  test "render_html with no plugins enabled — output unchanged" do
    Manto.Site.save(%{"plugins" => []})

    md = "# Just a heading\n\nSome text."
    html = Parser.render_html(md)

    assert html =~ ~s(<h1>Just a heading<a href="#just-a-heading">)
    assert html =~ "<p>Some text.</p>"
    refute html =~ "<ul>"
    refute html =~ "header-image-banner"
  end
end
