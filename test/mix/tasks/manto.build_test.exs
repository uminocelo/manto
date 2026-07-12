defmodule Mix.Tasks.Manto.BuildTest do
  use ExUnit.Case, async: false

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
end
