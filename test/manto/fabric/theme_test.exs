defmodule Manto.Fabric.ThemeTest do
  use ExUnit.Case, async: true
  alias Manto.Fabric.Theme

  describe "new/1" do
    test "returns a struct with defaults when called with empty map" do
      theme = Theme.new(%{})

      assert %Theme{} = theme
      assert theme.colors.primary.text == "#1f2937"
      assert theme.colors.primary.background == "#ffffff"
      assert theme.colors.secondary.text == "#4b5563"
      assert theme.colors.secondary.background == "#f3f4f6"
      assert theme.colors.accent.text == "#4f46e5"
      assert theme.colors.accent.background == "#eef2ff"

      assert theme.typography.font_heading == "inherit"

      assert theme.typography.font_body ==
               "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"

      assert theme.typography.font_code == "ui-monospace, monospace"
      assert theme.layout.page_width == "42rem"
      assert theme.layout.content_radius == "0.375rem"
      assert theme.custom_css == ""
    end

    test "overrides individual colour tokens" do
      theme = Theme.new(%{"colors" => %{"primary" => %{"background" => "#ff0000"}}})

      assert %Theme{} = theme
      assert theme.colors.primary.background == "#ff0000"
      assert theme.colors.primary.text == "#1f2937"
    end

    test "overrides typography tokens" do
      theme = Theme.new(%{"typography" => %{"font_body" => "Georgia, serif"}})

      assert %Theme{} = theme
      assert theme.typography.font_body == "Georgia, serif"
      assert theme.typography.font_code == "ui-monospace, monospace"
    end

    test "overrides layout tokens" do
      theme = Theme.new(%{"layout" => %{"page_width" => "60rem"}})

      assert %Theme{} = theme
      assert theme.layout.page_width == "60rem"
      assert theme.layout.content_radius == "0.375rem"
    end

    test "overrides multiple groups at once" do
      theme =
        Theme.new(%{
          "colors" => %{
            "primary" => %{"text" => "#111111", "background" => "#eeeeee"}
          },
          "typography" => %{"font_code" => "monospace"}
        })

      assert theme.colors.primary.text == "#111111"
      assert theme.colors.primary.background == "#eeeeee"
      assert theme.colors.accent.text == "#4f46e5"
      assert theme.typography.font_code == "monospace"
    end

    test "handles custom_css field" do
      theme = Theme.new(%{"custom_css" => "/path/to/custom.css"})
      assert theme.custom_css == "/path/to/custom.css"
    end

    test "returns error for invalid hex colour" do
      assert {:error, _} = Theme.new(%{"colors" => %{"primary" => %{"background" => "blue"}}})
    end

    test "returns error for invalid hex colour in any colour slot" do
      assert {:error, _} = Theme.new(%{"colors" => %{"accent" => %{"text" => "not-a-color"}}})
    end

    test "accepts valid hex with capital letters" do
      theme = Theme.new(%{"colors" => %{"primary" => %{"background" => "#ABCDEF"}}})
      assert theme.colors.primary.background == "#ABCDEF"
    end
  end
end
