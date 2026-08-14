defmodule Manto.ContentTest do
  use ExUnit.Case, async: false
  alias Manto.Content

  defp unique(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp write_page(name, body) do
    path = Path.join([:code.priv_dir(:manto), "content", "#{name}.md"])
    File.write!(path, body)
    on_exit(fn -> File.rm(path) end)
    name
  end

  test "list_pages/1 excludes drafts when include_drafts is false" do
    public = write_page(unique("Public"), "# Public")
    draft = write_page(unique("Draft"), "---\ndraft: true\n---\n# Draft")

    published = Content.list_pages(include_drafts: false)
    assert public in published
    refute draft in published
    assert draft in Content.list_pages()
  end

  test "draft?/1 reflects the page front matter" do
    draft = write_page(unique("Draft"), "---\ndraft: true\n---\n# Draft")
    public = write_page(unique("Public"), "# Public")

    assert Content.draft?(draft)
    refute Content.draft?(public)
    refute Content.draft?(unique("Missing"))
  end

  test "list_draft_pages/0 returns only draft pages" do
    write_page(unique("Public"), "# Public")
    draft = write_page(unique("Draft"), "---\ndraft: true\n---\n# Draft")

    assert draft in Content.list_draft_pages()
  end
end
