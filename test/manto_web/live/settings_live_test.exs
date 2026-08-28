defmodule MantoWeb.SettingsLiveTest do
  use MantoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Manto.Site

  defp unique_vault do
    Path.join(System.tmp_dir!(), "manto-vault-#{System.unique_integer([:positive])}")
  end

  test "renders the configuration form with defaults", %{conn: conn} do
    {:ok, view, html} = live(conn, "/")

    assert html =~ "Settings"
    assert html =~ ~s(value="priv/content")
    assert has_element?(view, "#settings-form")
    assert has_element?(view, "#vault_path")
    assert has_element?(view, "#title")
    assert has_element?(view, "#description")
    assert has_element?(view, "#base_url")
    assert has_element?(view, "#vault-summary")
  end

  test "saves settings to manto.json and creates the vault directory", %{conn: conn} do
    vault = unique_vault()

    on_exit(fn ->
      File.rm(Site.config_path())
      File.rm_rf(vault)
    end)

    {:ok, view, _html} = live(conn, "/")

    html =
      view
      |> form("#settings-form", %{
        vault_path: vault,
        title: "My Vault",
        description: "My notes",
        base_url: "https://example.com"
      })
      |> render_submit()

    assert html =~ "Settings saved."

    config = Site.config()
    assert config["vault_path"] == vault
    assert config["title"] == "My Vault"
    assert config["description"] == "My notes"
    assert config["base_url"] == "https://example.com"
    assert File.dir?(vault)
  end

  test "rejects a vault path that points at a file", %{conn: conn} do
    file = Path.join(System.tmp_dir!(), "manto-file-#{System.unique_integer([:positive])}")
    File.write!(file, "not a directory")
    on_exit(fn -> File.rm(file) end)

    {:ok, view, _html} = live(conn, "/")

    html =
      view
      |> form("#settings-form", %{vault_path: file})
      |> render_submit()

    assert html =~ "not a directory"
    refute Site.config()["vault_path"] == file
  end

  test "rejects a vault path whose leading ~ cannot be expanded", %{conn: conn} do
    bogus = "~not-a-real-user-123/manto-vault"

    {:ok, view, _html} = live(conn, "/")

    html =
      view
      |> form("#settings-form", %{vault_path: bogus})
      |> render_submit()

    assert html =~ "Could not expand"
    refute Site.config()["vault_path"] == bogus
    refute File.exists?(Path.expand(bogus))
  end

  test "expands a ~/ vault path to the home directory", %{conn: conn} do
    vault = Path.join(Path.expand("~"), "manto-vault-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf(vault) end)

    {:ok, view, _html} = live(conn, "/")

    html =
      view
      |> form("#settings-form", %{vault_path: "~/#{Path.relative_to(vault, Path.expand("~"))}"})
      |> render_submit()

    assert html =~ "Settings saved."
    assert File.dir?(vault)
  end

  test "renders a checkbox for each available plugin", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "Plugins"
    assert html =~ "Table of Contents"
    assert html =~ "Header Image Banner"

    assert html =~ ~s(name="plugins[]" value="toc")
    assert html =~ ~s(name="plugins[]" value="header_image")
  end

  test "enabling a plugin via form submit persists it to manto.json", %{conn: conn} do
    vault = unique_vault()

    on_exit(fn ->
      File.rm(Site.config_path())
      File.rm_rf(vault)
    end)

    {:ok, view, _html} = live(conn, "/")

    view
    |> form("#settings-form", %{
      vault_path: vault,
      title: "Plugin Site",
      description: "Testing",
      base_url: "",
      plugins: ["toc"]
    })
    |> render_submit()

    config = Site.config()
    assert config["plugins"] == ["toc"]
  end

  test "disabling a plugin removes it from manto.json", %{conn: conn} do
    vault = unique_vault()

    on_exit(fn ->
      File.rm(Site.config_path())
      File.rm_rf(vault)
    end)

    Site.save(%{"plugins" => ["toc", "header_image"], "vault_path" => vault})

    {:ok, view, _html} = live(conn, "/")

    view
    |> form("#settings-form", %{
      vault_path: vault,
      title: "Plugin Site",
      description: "Testing",
      base_url: "",
      plugins: []
    })
    |> render_submit()

    config = Site.config()
    assert config["plugins"] == []
  end
end
