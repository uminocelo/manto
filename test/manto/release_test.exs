defmodule Manto.ReleaseTest do
  use ExUnit.Case, async: false

  alias Manto.Release

  setup do
    vault = Path.join(System.tmp_dir!(), "manto-release-#{System.unique_integer([:positive])}")
    File.mkdir_p!(vault)

    config_path =
      Path.join(System.tmp_dir!(), "manto-release-cfg-#{System.unique_integer([:positive])}.json")

    previous = Application.get_env(:manto, :config_path)
    Application.put_env(:manto, :config_path, config_path)
    File.write!(config_path, Jason.encode!(%{"vault_path" => vault}))

    on_exit(fn ->
      if previous, do: Application.put_env(:manto, :config_path, previous)

      File.rm_rf!(vault)
      File.rm(config_path)
    end)

    %{vault: vault}
  end

  test "seeds welcome.md into an empty vault", %{vault: vault} do
    assert Manto.Content.list_pages() == []
    assert Release.init() == :seeded

    assert Manto.Content.list_pages() == ["welcome"]
    assert File.exists?(Path.join(vault, "welcome.md"))
  end

  test "does not touch a vault that already has pages", %{vault: vault} do
    File.write!(Path.join(vault, "existing.md"), "# Existing")

    assert Manto.Content.list_pages() == ["existing"]
    assert Release.init() == :ok
    assert Manto.Content.list_pages() == ["existing"]
    refute File.exists?(Path.join(vault, "welcome.md"))
  end
end
