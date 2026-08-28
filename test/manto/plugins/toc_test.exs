defmodule Manto.Plugins.TOCTest do
  use ExUnit.Case, async: true
  alias Manto.Plugins.TOC

  test "generates TOC with multiple heading levels (h1-h3)" do
    md = """
    # Title

    ## Section One

    ### Subsection A

    ## Section Two
    """

    result = TOC.transform_markdown(md)

    assert result =~ ~S"[Title](#title)"
    assert result =~ ~S"[Section One](#section-one)"
    assert result =~ ~S"[Subsection A](#subsection-a)"
    assert result =~ ~S"[Section Two](#section-two)"

    # Verify nesting: subsection should be indented relative to section
    lines = String.split(result, "\n")
    subsection_line = Enum.find(lines, &(&1 =~ "Subsection A"))
    assert String.starts_with?(subsection_line, "  ")
  end

  test "TOC with no headings returns input unchanged" do
    md = "Just some plain text.\nNo headings here."

    assert TOC.transform_markdown(md) == md
  end

  test "TOC with <!-- toc --> insertion point places TOC there" do
    md = """
    # Title

    <!-- toc -->

    ## Section One

    ## Section Two
    """

    result = TOC.transform_markdown(md)

    # The <!-- toc --> comment should be replaced with the TOC
    refute result =~ "<!-- toc -->"

    # TOC should appear between Title and Section One
    title_idx = String.split(result, "\n") |> Enum.find_index(&(&1 =~ "# Title"))
    toc_idx = String.split(result, "\n") |> Enum.find_index(&(&1 =~ "[Section One]"))
    section_idx = String.split(result, "\n") |> Enum.find_index(&(&1 =~ "## Section One"))

    assert title_idx < toc_idx
    assert toc_idx < section_idx
  end

  test "heading slug generation handles special chars, spaces, and unicode" do
    md = "# Hello, World!\n## Café & Co.\n### Foo / Bar"

    result = TOC.transform_markdown(md)

    assert result =~ ~S"[Hello, World!](#hello-world)"
    assert result =~ ~S"[Café & Co.](#café-co)"
    assert result =~ ~S"[Foo / Bar](#foo-bar)"
  end
end
