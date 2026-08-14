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
end
