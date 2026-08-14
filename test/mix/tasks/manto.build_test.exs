defmodule Mix.Tasks.Manto.BuildTest do
  use ExUnit.Case, async: false

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
end
