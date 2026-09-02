defmodule Manto.Fabric.PageTemplateTest do
  use ExUnit.Case, async: true
  alias Manto.Fabric.PageTemplate

  @site %{"title" => "Test Site"}

  describe "render/1" do
    test "renders a full HTML document" do
      html = render()

      assert html =~ ~r/<!DOCTYPE html>/
      assert html =~ ~r/<html lang="en">/
      assert html =~ ~r/<\/html>/
    end

    test "includes the page title and site title" do
      html = render(title: "My Page")

      assert html =~ "<title>My Page · Test Site</title>"
    end

    test "includes the body content" do
      html = render(body: "<p>Hello!</p>")

      assert html =~ "<p>Hello!</p>"
    end

    test "renders breadcrumb navigation" do
      html = render()

      assert html =~ ~r/<nav>/
      assert html =~ ~r/Home/
    end

    test "includes a stylesheet link by default" do
      html = render()

      assert html =~ ~r/<link rel="stylesheet" href="style.css" \/>/
    end

    test "uses custom stylesheet_href when provided" do
      html = render(stylesheet_href: "/custom.css")

      assert html =~ ~r/<link rel="stylesheet" href="\/custom.css" \/>/
    end

    test "uses inline_style when provided, excluding stylesheet link" do
      html = render(stylesheet_href: "/custom.css", inline_style: "body { color: red; }")

      assert html =~ ~r/<style>/
      assert html =~ "body { color: red; }"
      refute html =~ ~r/<link rel="stylesheet"/
    end

    test "includes published date when present" do
      html = render(published_at: "2024-01-15")

      assert html =~ ~r/<p class="published">/
      assert html =~ "Published on 2024-01-15"
    end

    test "includes updated date when present" do
      html = render(updated_at: "2024-06-01")

      assert html =~ ~r/<p class="updated">/
      assert html =~ "Updated on 2024-06-01"
    end

    test "includes tags when present" do
      html = render(tags: ["elixir", "phoenix"])

      assert html =~ ~r/<p class="tags">/
      assert html =~ "elixir"
      assert html =~ "phoenix"
    end

    test "does not include tags section when tags is empty" do
      html = render(tags: [])

      refute html =~ ~r/<p class="tags">/
    end

    test "computes prefix-based stylesheet href for nested pages" do
      html = render(prefix: "../", current: "docs/guide")

      assert html =~ ~r/<link rel="stylesheet" href="\.\.\/style.css" \/>/
    end

    test "breadcrumb for nested page shows folder hierarchy" do
      html = render(prefix: "../", current: "docs/guide")

      assert html =~ "Home"
      assert html =~ ~r|docs/index\.html|
      assert html =~ "guide"
    end
  end

  describe "breadcrumb_html/2" do
    test "root page shows only Home link" do
      html = PageTemplate.breadcrumb_html("index", "")

      assert html =~ ~r/Home/
      assert html =~ ~r/index\.html/
    end

    test "nested page shows folder hierarchy" do
      html = PageTemplate.breadcrumb_html("docs/guide/setup", "../..")

      assert html =~ ~r/Home/
      assert html =~ ~r|docs/index\.html|
      assert html =~ ~r|guide/index\.html|
      assert html =~ "setup"
    end
  end

  describe "tag_link/2" do
    test "generates a tag link with slug" do
      html = PageTemplate.tag_link("", "Elixir")
      assert html =~ ~r|<a href="tag/elixir\.html">Elixir</a>|
    end

    test "uses prefix in href" do
      html = PageTemplate.tag_link("../", "Elixir")
      assert html =~ ~r|\.\.\/tag/elixir\.html|
    end
  end

  describe "tag_slug/1" do
    test "lowercases and replaces spaces with hyphens" do
      assert PageTemplate.tag_slug("Hello World") == "hello-world"
    end

    test "trims whitespace" do
      assert PageTemplate.tag_slug("  elixir  ") == "elixir"
    end
  end

  defp render(overrides \\ []) do
    assigns =
      [
        site: @site,
        title: "Hello World",
        body: "<p>Hello, world!</p>",
        prefix: "",
        current: "hello"
      ]
      |> Keyword.merge(overrides)

    PageTemplate.render(assigns)
  end
end
