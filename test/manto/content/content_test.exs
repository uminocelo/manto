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

  test "content_dir/0 resolves the configured vault path" do
    previous = Application.get_env(:manto, :site)
    Application.put_env(:manto, :site, %{vault_path: "custom-vault"})

    on_exit(fn ->
      if previous do
        Application.put_env(:manto, :site, previous)
      else
        Application.delete_env(:manto, :site)
      end
    end)

    assert Content.content_dir() == Path.expand("custom-vault")
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

  test "delete_page/1 removes the page file" do
    page = write_page(unique("Delete"), "# Delete me")
    assert :ok = Content.delete_page(page)
    refute page in Content.list_pages()
  end

  test "delete_page/1 returns :not_found for a missing page" do
    assert {:error, :not_found} = Content.delete_page(unique("Missing"))
  end

  test "rename_page/2 renames the page file" do
    from = write_page(unique("Rename"), "# Rename me")
    to = unique("Renamed")
    on_exit(fn -> File.rm(Path.join([:code.priv_dir(:manto), "content", "#{to}.md"])) end)

    assert :ok = Content.rename_page(from, to)
    refute from in Content.list_pages()
    assert to in Content.list_pages()
    assert Content.get_page(to) == "# Rename me"
  end

  test "rename_page/2 guards against missing sources and existing targets" do
    assert {:error, :not_found} = Content.rename_page(unique("Missing"), unique("Target"))

    from = write_page(unique("RenameFrom"), "# From")
    existing = write_page(unique("Existing"), "# Existing")
    assert {:error, :already_exists} = Content.rename_page(from, existing)
  end

  test "list_pages/1 returns pages in subfolders with their folder path" do
    folder = "nested-#{System.unique_integer([:positive])}"
    path = Path.join([:code.priv_dir(:manto), "content", folder, "guide.md"])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, "# Guide")
    on_exit(fn -> File.rm_rf!(Path.dirname(path)) end)

    assert "#{folder}/guide" in Content.list_pages()
  end

  test "save_page/2 creates missing folders" do
    folder = "created-#{System.unique_integer([:positive])}"
    page = "#{folder}/page"
    on_exit(fn -> File.rm_rf!(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    Content.save_page(page, "# Created")

    assert Content.get_page(page) == "# Created"
    assert page in Content.list_pages()
  end

  test "rename_page/2 moves a page between folders" do
    from = write_page(unique("MoveFrom"), "# Move")
    folder = "moved-into-#{System.unique_integer([:positive])}"
    to = "#{folder}/moved"
    on_exit(fn -> File.rm_rf!(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    assert :ok = Content.rename_page(from, to)
    refute from in Content.list_pages()
    assert to in Content.list_pages()
    assert Content.get_page(to) == "# Move"
  end

  test "valid_page_name?/1 accepts nested slugs and rejects traversal" do
    assert Content.valid_page_name?("welcome")
    assert Content.valid_page_name?("docs/guides/setup")

    refute Content.valid_page_name?("")
    refute Content.valid_page_name?("../escape")
    refute Content.valid_page_name?("a/../../escape")
    refute Content.valid_page_name?("/absolute")
    refute Content.valid_page_name?("a//b")
    refute Content.valid_page_name?("a/./b")
    refute Content.valid_page_name?("a/")
  end

  test "broken_wiki_links/3 flags only missing targets" do
    existing = write_page(unique("Existing"), "# Existing")

    assert Content.broken_wiki_links("See [[#{existing}]] and [[Nope-ABC]].") == ["Nope-ABC"]
  end

  test "broken_wiki_links/3 ignores self-links" do
    page = unique("Self")
    write_page(page, "See [[#{page}]] and [[Nope-ABC]].")

    assert Content.broken_wiki_links("See [[#{page}]] and [[Nope-ABC]].", page) == ["Nope-ABC"]
  end

  test "broken_wiki_links/3 treats draft targets as broken when publishing only" do
    draft = write_page(unique("Draft"), "---\ndraft: true\n---\n# Draft")

    assert Content.broken_wiki_links("See [[#{draft}]].") == []
    assert Content.broken_wiki_links("See [[#{draft}]].", nil, include_drafts: false) == [draft]
  end
end
