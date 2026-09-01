defmodule Manto.Fabric.ThemeTest do
  use ExUnit.Case, async: true
  alias Manto.Fabric.Theme

  describe "new/1" do
    test "returns a struct with defaults when called with empty map" do
      theme = Theme.new(%{})

      assert %Theme{} = theme
      assert theme.colors.text == "#1f2937"
      assert theme.colors.background == "#ffffff"
      assert theme.colors.link == "#4f46e5"
      assert theme.colors.pre_background == "#f3f4f6"
      assert theme.typography.font_body == "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
      assert theme.typography.font_code == "ui-monospace, monospace"
      assert theme.layout.content_width == "42rem"
      assert theme.layout.content_radius == "0.375rem"
    end

    test "overrides individual colour tokens" do
      theme = Theme.new(%{"colors" => %{"background" => "#ff0000"}})

      assert theme.colors.background == "#ff0000"
      assert theme.colors.text == "#1f2937"
    end

    test "overrides typography tokens" do
      theme = Theme.new(%{"typography" => %{"font_body" => "Georgia, serif"}})

      assert theme.typography.font_body == "Georgia, serif"
      assert theme.typography.font_code == "ui-monospace, monospace"
    end

    test "overrides layout tokens" do
      theme = Theme.new(%{"layout" => %{"content_width" => "60rem"}})

      assert theme.layout.content_width == "60rem"
      assert theme.layout.content_radius == "0.375rem"
    end

    test "overrides multiple groups at once" do
      theme =
        Theme.new(%{
          "colors" => %{"text" => "#111111", "background" => "#eeeeee"},
          "typography" => %{"font_code" => "monospace"}
        })

      assert theme.colors.text == "#111111"
      assert theme.colors.background == "#eeeeee"
      assert theme.colors.link == "#4f46e5"
      assert theme.typography.font_code == "monospace"
    end

    test "returns error for invalid hex colour" do
      assert {:error, reason} = Theme.new(%{"colors" => %{"background" => "blue"}})
      assert reason =~ "blue"
      assert reason =~ "background"
    end

    test "returns error for invalid hex colour in any colour slot" do
      assert {:error, _reason} = Theme.new(%{"colors" => %{"text" => "not-hex"}})
      assert {:error, _reason} = Theme.new(%{"colors" => %{"link" => "#zzzzzz"}})
    end

    test "accepts valid hex with capital letters" do
      theme = Theme.new(%{"colors" => %{"background" => "#ABCDEF"}})
      assert theme.colors.background == "#ABCDEF"
    end
  end
end