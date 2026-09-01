defmodule Manto.FabricTest do
  use ExUnit.Case, async: false
  alias Manto.Fabric
  alias Manto.Fabric.Theme
  alias Manto.Site

  describe "render_css/1" do
    test "output starts with :root block" do
      css = Fabric.render_css(Theme.new(%{}))

      assert String.starts_with?(css, ":root {")
    end

    test "contains all expected CSS variable declarations" do
      css = Fabric.render_css(Theme.new(%{}))

      assert css =~ "--fabric-color-text: #1f2937;"
      assert css =~ "--fabric-color-bg: #ffffff;"
      assert css =~ "--fabric-color-link: #4f46e5;"
      assert css =~ "--fabric-color-pre-bg: #f3f4f6;"
      assert css =~ "--fabric-font-body: -apple-system, BlinkMacSystemFont"
      assert css =~ "--fabric-font-code: ui-monospace, monospace;"
      assert css =~ "--fabric-content-width: 42rem;"
      assert css =~ "--fabric-content-radius: 0.375rem;"
    end

    test "includes the base template" do
      css = Fabric.render_css(Theme.new(%{}))

      assert css =~ "body {"
      assert css =~ "var(--fabric-content-width)"
      assert css =~ "var(--fabric-font-body)"
      assert css =~ "var(--fabric-color-text)"
      assert css =~ "var(--fabric-color-bg)"
      assert css =~ "nav {"
      assert css =~ "a {"
      assert css =~ "var(--fabric-color-link)"
      assert css =~ "pre {"
      assert css =~ "var(--fabric-color-pre-bg)"
      assert css =~ "var(--fabric-content-radius)"
      assert css =~ "code {"
      assert css =~ "var(--fabric-font-code)"
    end

    test "has balanced braces" do
      css = Fabric.render_css(Theme.new(%{}))

      opening = String.graphemes(css) |> Enum.count(fn c -> c == "{" end)
      closing = String.graphemes(css) |> Enum.count(fn c -> c == "}" end)

      assert opening == closing, "Expected balanced braces, got #{opening} open / #{closing} close"
    end

    test "default and dark presets produce distinct output" do
      {:ok, default} = Manto.Fabric.Presets.get("default")
      {:ok, dark} = Manto.Fabric.Presets.get("dark")

      default_css = Fabric.render_css(default)
      dark_css = Fabric.render_css(dark)

      assert default_css != dark_css
      assert dark_css =~ "--fabric-color-bg: #111827;"
      assert dark_css =~ "--fabric-color-text: #e5e7eb;"
    end

    test "custom theme variables appear in output" do
      theme =
        Theme.new(%{
          "colors" => %{"background" => "#ff0000", "text" => "#00ff00"},
          "layout" => %{"content_width" => "60rem"}
        })

      css = Fabric.render_css(theme)

      assert css =~ "--fabric-color-bg: #ff0000;"
      assert css =~ "--fabric-color-text: #00ff00;"
      assert css =~ "--fabric-content-width: 60rem;"
    end

    test "default preset renders equivalent to original default.css" do
      {:ok, theme} = Manto.Fabric.Presets.get("default")
      css = Fabric.render_css(theme)

      assert css =~ "--fabric-color-text: #1f2937;"
      assert css =~ "--fabric-color-bg: #ffffff;"
      assert css =~ "--fabric-color-link: #4f46e5;"
      assert css =~ "--fabric-color-pre-bg: #f3f4f6;"
      assert css =~ "--fabric-content-width: 42rem;"
      assert css =~ "--fabric-content-radius: 0.375rem;"
    end

    test "dark preset renders equivalent to original dark.css" do
      {:ok, theme} = Manto.Fabric.Presets.get("dark")
      css = Fabric.render_css(theme)

      assert css =~ "--fabric-color-text: #e5e7eb;"
      assert css =~ "--fabric-color-bg: #111827;"
      assert css =~ "--fabric-color-link: #818cf8;"
      assert css =~ "--fabric-color-pre-bg: #1f2937;"
    end
  end

  describe "themes CRUD" do
    setup do
      path = Path.join(System.tmp_dir!(), "manto-fabric-#{System.unique_integer([:positive])}.json")
      prev = Application.get_env(:manto, :config_path)
      Application.put_env(:manto, :config_path, path)
      on_exit(fn -> File.rm(path); restore_config(prev) end)
      %{_path: path}
    end

    defp restore_config(prev) do
      if prev, do: Application.put_env(:manto, :config_path, prev), else: Application.delete_env(:manto, :config_path)
    end

    test "save_theme/2 persists a custom theme under fabric.themes" do
      Fabric.save_theme("Blog", %{"colors" => %{"background" => "#f0f0f0"}})

      config = Site.config()
      assert get_in(config, ["fabric", "themes", "Blog"]) == %{"colors" => %{"background" => "#f0f0f0"}}
    end

    test "save_theme/2 preserves existing themes" do
      Fabric.save_theme("Blog", %{"colors" => %{"background" => "#f0f0f0"}})
      Fabric.save_theme("Portfolio", %{"colors" => %{"text" => "#222222"}})

      config = Site.config()
      assert get_in(config, ["fabric", "themes", "Blog"])
      assert get_in(config, ["fabric", "themes", "Portfolio"])
    end

    test "list_themes/0 includes built-ins and customs" do
      Fabric.save_theme("Blog", %{"colors" => %{"background" => "#f0f0f0"}})

      themes = Fabric.list_themes()

      assert Enum.any?(themes, &(&1.name == "default" and &1.type == :builtin))
      assert Enum.any?(themes, &(&1.name == "dark" and &1.type == :builtin))
      assert Enum.any?(themes, &(&1.name == "Blog" and &1.type == :custom))
    end

    test "get_theme/1 returns built-in presets" do
      assert {:ok, %Theme{} = theme} = Fabric.get_theme("default")
      assert theme.colors.background == "#ffffff"
    end

    test "get_theme/1 returns custom themes" do
      Fabric.save_theme("Blog", %{"colors" => %{"background" => "#f0f0f0"}})

      assert {:ok, %Theme{} = theme} = Fabric.get_theme("Blog")
      assert theme.colors.background == "#f0f0f0"
    end

    test "get_theme/1 returns :error for unknown theme" do
      assert Fabric.get_theme("nonexistent") == :error
    end

    test "set_active/1 updates the active theme" do
      Fabric.set_active("dark")

      config = Site.config()
      assert config["fabric"]["active"] == "dark"
    end

    test "active_theme/0 returns the current active theme struct" do
      Fabric.set_active("dark")

      theme = Fabric.active_theme()
      assert %Theme{} = theme
      assert theme.colors.background == "#111827"
    end

    test "delete_theme/1 refuses built-in presets" do
      assert Fabric.delete_theme("default") == {:error, :builtin}
      assert Fabric.delete_theme("dark") == {:error, :builtin}
    end

    test "delete_theme/1 refuses the active theme" do
      Fabric.save_theme("Blog", %{"colors" => %{"background" => "#f0f0f0"}})
      Fabric.set_active("Blog")

      assert Fabric.delete_theme("Blog") == {:error, :active}
    end

    test "delete_theme/1 removes a custom theme" do
      Fabric.save_theme("Blog", %{"colors" => %{"background" => "#f0f0f0"}})

      assert Fabric.delete_theme("Blog") == :ok
      assert Fabric.get_theme("Blog") == :error
    end

    test "set_active and get_theme round-trip through Site.config" do
      Fabric.save_theme("Blog", %{"colors" => %{"text" => "#333333"}})
      Fabric.set_active("Blog")

      {:ok, theme} = Fabric.get_theme("Blog")
      assert theme.colors.text == "#333333"

      config = Site.config()
      assert config["fabric"]["active"] == "Blog"
    end
  end
end