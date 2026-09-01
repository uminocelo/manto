defmodule Mix.Tasks.Manto.BuildTest do
  use ExUnit.Case, async: false

  setup do
    config_path = Manto.Site.config_path()
    File.rm(config_path)
    on_exit(fn -> File.rm(config_path) end)
  end

  defp drain_shell_messages(acc \\ []) do
    receive do
      {:mix_shell, :info, [line]} -> drain_shell_messages([line | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  test "builds each page into a themed static HTML file" do
    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_test_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir])

    assert File.exists?(Path.join(output_dir, "style.css"))
    assert File.exists?(Path.join(output_dir, "welcome.html"))

    html = File.read!(Path.join(output_dir, "welcome.html"))
    assert html =~ ~s(<link rel="stylesheet" href="style.css" />)

    File.rm_rf!(output_dir)
  end

  test "raises for an unknown theme" do
    assert_raise Mix.Error, ~r/Unknown theme/, fn ->
      Mix.Task.rerun("manto.build", ["--theme", "does-not-exist"])
    end
  end

  test "reports broken wiki links as build warnings" do
    page = "Broken-Build-#{System.unique_integer([:positive])}"
    path = Path.join([:code.priv_dir(:manto), "content", "#{page}.md"])

    File.write!(path, "See [[Does-Not-Exist-ABC]] and [[Other-Missing]].")
    on_exit(fn -> File.rm(path) end)

    previous_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(previous_shell) end)

    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_broken_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir])

    lines = drain_shell_messages()
    assert Enum.any?(lines, &(&1 =~ "Broken links:"))
    assert Enum.any?(lines, &(&1 =~ "#{page}.html" and &1 =~ "Does-Not-Exist-ABC"))
    assert Enum.any?(lines, &(&1 =~ "Other-Missing"))

    File.rm_rf!(output_dir)
  end

  test "skips draft pages and renders published/updated dates" do
    draft = "Draft-#{System.unique_integer([:positive])}"
    draft_path = Path.join([:code.priv_dir(:manto), "content", "#{draft}.md"])

    File.write!(draft_path, """
    ---
    draft: true
    ---
    # Draft
    """)

    on_exit(fn -> File.rm(draft_path) end)

    published_path = Path.join([:code.priv_dir(:manto), "content", "welcome.md"])
    original = File.read!(published_path)
    on_exit(fn -> File.write!(published_path, original) end)

    File.write!(published_path, """
    ---
    title: Welcome to Manto!
    published_at: 2026-08-13
    updated_at: 2026-08-13
    ---

    # This is Manto!
    """)

    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_draft_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir])

    refute File.exists?(Path.join(output_dir, "#{draft}.html"))
    assert File.exists?(Path.join(output_dir, "welcome.html"))

    html = File.read!(Path.join(output_dir, "welcome.html"))
    assert html =~ ~s(<p class="published">Published on 2026-08-13</p>)
    assert html =~ ~s(<p class="updated">Updated on 2026-08-13</p>)

    File.rm_rf!(output_dir)
  end

  test "generates index, rss, and sitemap alongside pages" do
    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_feed_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir])

    index = File.read!(Path.join(output_dir, "index.html"))
    assert index =~ ~s(<h1>Manto</h1>)
    assert index =~ ~s(<a href="welcome.html">Welcome to Manto!</a>)

    rss = File.read!(Path.join(output_dir, "rss.xml"))
    assert rss =~ ~s(<rss version="2.0">)
    assert rss =~ "<title>Manto</title>"
    assert rss =~ ~s(<link>/welcome.html</link>)

    sitemap = File.read!(Path.join(output_dir, "sitemap.xml"))
    assert sitemap =~ ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)
    assert sitemap =~ ~s(<loc>/welcome.html</loc>)

    File.rm_rf!(output_dir)
  end

  test "renders pubDate and base_url from site config in the feed" do
    previous = Application.get_env(:manto, :site)

    Application.put_env(:manto, :site, %{base_url: "https://example.com"})

    on_exit(fn ->
      if previous do
        Application.put_env(:manto, :site, previous)
      else
        Application.delete_env(:manto, :site)
      end
    end)

    page = "Feed-Page-#{System.unique_integer([:positive])}"
    path = Path.join([:code.priv_dir(:manto), "content", "#{page}.md"])

    File.write!(path, """
    ---
    title: Feed Post
    published_at: 2026-08-13
    ---

    # Feed Post
    """)

    on_exit(fn -> File.rm(path) end)

    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_feed2_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir])

    rss = File.read!(Path.join(output_dir, "rss.xml"))
    assert rss =~ ~s(<link>https://example.com/#{page}.html</link>)
    assert rss =~ "<pubDate>Thu, 13 Aug 2026 00:00:00 +0000</pubDate>"

    sitemap = File.read!(Path.join(output_dir, "sitemap.xml"))
    assert sitemap =~ ~s(<loc>https://example.com/#{page}.html</loc>)

    File.rm_rf!(output_dir)
  end

  test "copies content images into the output" do
    image =
      Path.join([
        :code.priv_dir(:manto),
        "content",
        "build-test-#{System.unique_integer([:positive])}.png"
      ])

    File.write!(image, "fake png")
    on_exit(fn -> File.rm(image) end)

    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_img_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir])

    assert File.exists?(Path.join(output_dir, Path.basename(image)))

    File.rm_rf!(output_dir)
  end

  test "builds tag taxonomy pages from front matter tags" do
    tagged = "Tagged-Build-#{System.unique_integer([:positive])}"
    tagged_path = Path.join([:code.priv_dir(:manto), "content", "#{tagged}.md"])

    File.write!(tagged_path, """
    ---
    title: Tagged Page
    tags: elixir, phoenix
    ---

    # Tagged Page
    """)

    on_exit(fn -> File.rm(tagged_path) end)

    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_tags_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir])

    elixir = File.read!(Path.join([output_dir, "tag", "elixir.html"]))
    assert elixir =~ ~s(<h1>Tag: elixir</h1>)
    assert elixir =~ ~s(href="../#{tagged}.html")

    assert File.exists?(Path.join([output_dir, "tag", "phoenix.html"]))

    html = File.read!(Path.join(output_dir, "#{tagged}.html"))
    assert html =~ ~s(<p class="tags">)
    assert html =~ ~s(href="tag/elixir.html")

    File.rm_rf!(output_dir)
  end

  test "builds nested pages into their folders with a breadcrumb trail" do
    folder = "build-docs-#{System.unique_integer([:positive])}"
    page = "#{folder}/Nested-Page"
    Manto.Content.save_page(page, "# Nested")
    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_nested_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir])

    nested = File.read!(Path.join([output_dir, folder, "Nested-Page.html"]))

    assert nested =~ ~s(<link rel="stylesheet" href="../style.css" />)
    assert nested =~ ~s(<a href="../index.html">Home</a>)
    assert nested =~ ~s(<a href="../#{folder}/index.html">#{folder}</a>)
    assert nested =~ "Nested-Page"

    File.rm_rf!(output_dir)
  end

  test "generates a folder index listing its pages and subfolders" do
    folder = "build-index-#{System.unique_integer([:positive])}"
    page = "#{folder}/Top-Level"
    sub = "#{folder}/guides/Setup"
    Manto.Content.save_page(page, "# Top")
    Manto.Content.save_page(sub, "# Setup")
    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_folders_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir])

    index = File.read!(Path.join([output_dir, folder, "index.html"]))
    assert index =~ ~s(<link rel="stylesheet" href="../style.css" />)
    assert index =~ ~s(<a href="../#{page}.html">Top-Level</a>)
    assert index =~ ~s(<a href="../#{folder}/guides/index.html">guides/</a>)

    sub_index = File.read!(Path.join([output_dir, folder, "guides", "index.html"]))
    assert sub_index =~ ~s(<a href="../../index.html">Home</a>)
    assert sub_index =~ ~s(<a href="../../#{folder}/index.html">#{folder}</a>)
    assert sub_index =~ ~s(<a href="../../#{sub}.html">Setup</a>)

    root = File.read!(Path.join(output_dir, "index.html"))
    assert root =~ ~s(<a href="#{folder}/index.html">#{folder}/</a>)

    File.rm_rf!(output_dir)
  end

  test "an explicit <folder>/index page wins over the auto-generated index" do
    folder = "build-explicit-#{System.unique_integer([:positive])}"
    page = "#{folder}/index"
    Manto.Content.save_page(page, "# My Custom Index")
    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_explicit_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir])

    html = File.read!(Path.join([output_dir, folder, "index.html"]))
    assert html =~ ~s(<h1>My Custom Index</h1>)
    refute html =~ ~s(<h1>#{folder}</h1>)

    File.rm_rf!(output_dir)
  end

  test "wiki links in nested pages resolve relative to the root" do
    folder = "build-wiki-#{System.unique_integer([:positive])}"
    nested = "#{folder}/With-Link"
    Manto.Content.save_page(nested, "See [[welcome]] and [[#{folder}/Other]].")
    Manto.Content.save_page("#{folder}/Other", "# Other")
    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_wiki_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir])

    html = File.read!(Path.join([output_dir, folder, "With-Link.html"]))
    assert html =~ ~s(href="../welcome.html")
    assert html =~ ~s(href="../#{folder}/Other.html")

    File.rm_rf!(output_dir)
  end

  test "skips nested draft pages and leaves them out of indexes" do
    folder = "build-nested-draft-#{System.unique_integer([:positive])}"
    draft = "#{folder}/Secret"

    Manto.Content.save_page(draft, """
    ---
    draft: true
    ---

    # Secret
    """)

    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_ndraft_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir])

    refute File.exists?(Path.join([output_dir, folder, "Secret.html"]))
    refute File.exists?(Path.join([output_dir, folder, "index.html"]))

    root = File.read!(Path.join(output_dir, "index.html"))
    refute root =~ "Secret"

    File.rm_rf!(output_dir)
  end

  test "includes nested page URLs in the rss feed and sitemap" do
    folder = "build-feed-nested-#{System.unique_integer([:positive])}"
    page = "#{folder}/Nested-Feed"
    Manto.Content.save_page(page, "# Nested Feed")
    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_nfeed_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir])

    rss = File.read!(Path.join(output_dir, "rss.xml"))
    assert rss =~ ~s(<link>/#{page}.html</link>)
    assert rss =~ ~s(<guid>/#{page}.html</guid>)

    sitemap = File.read!(Path.join(output_dir, "sitemap.xml"))
    assert sitemap =~ ~s(<loc>/#{page}.html</loc>)

    File.rm_rf!(output_dir)
  end

  test "tag pages link back to nested pages" do
    folder = "build-tag-nested-#{System.unique_integer([:positive])}"
    page = "#{folder}/Tagged-Nested"

    Manto.Content.save_page(page, """
    ---
    title: Tagged Nested
    tags: nested-tag
    ---

    # Tagged Nested
    """)

    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_ntag_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir])

    tag = File.read!(Path.join([output_dir, "tag", "nested-tag.html"]))
    assert tag =~ ~s(href="../#{page}.html")

    File.rm_rf!(output_dir)
  end

  test "--theme default builds successfully with the default preset" do
    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_theme_def_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir, "--theme", "default"])

    style = File.read!(Path.join(output_dir, "style.css"))
    assert style =~ "var(--fabric-color-text)"
    assert style =~ "#1f2937"
    File.rm_rf!(output_dir)
  end

  test "--theme dark builds successfully with the dark preset" do
    output_dir =
      Path.join(System.tmp_dir!(), "manto_build_theme_dark_#{System.unique_integer([:positive])}")

    Mix.Task.rerun("manto.build", ["--output", output_dir, "--theme", "dark"])

    style = File.read!(Path.join(output_dir, "style.css"))
    assert style =~ "var(--fabric-color-bg)"
    assert style =~ "#111827"
    File.rm_rf!(output_dir)
  end

  test "unknown --theme raises a helpful error" do
    assert_raise Mix.Error, ~r/Unknown theme/, fn ->
      Mix.Task.rerun("manto.build", ["--theme", "nonexistent"])
    end
  end
end
