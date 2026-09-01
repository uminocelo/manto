defmodule Manto.Fabric.PresetsTest do
  use ExUnit.Case, async: true
  alias Manto.Fabric.{Presets, Theme}

  describe "list/0" do
    test "returns both built-in preset names" do
      names = Presets.list()
      assert "default" in names
      assert "dark" in names
    end
  end

  describe "get/1" do
    test "returns the default preset" do
      assert {:ok, %Theme{} = theme} = Presets.get("default")
      assert theme.colors.text == "#1f2937"
      assert theme.colors.background == "#ffffff"
      assert theme.colors.link == "#4f46e5"
      assert theme.colors.pre_background == "#f3f4f6"
      assert theme.typography.font_body == "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
      assert theme.typography.font_code == "ui-monospace, monospace"
      assert theme.layout.content_width == "42rem"
      assert theme.layout.content_radius == "0.375rem"
    end

    test "returns the dark preset matching priv/themes/dark.css" do
      assert {:ok, %Theme{} = theme} = Presets.get("dark")
      assert theme.colors.text == "#e5e7eb"
      assert theme.colors.background == "#111827"
      assert theme.colors.link == "#818cf8"
      assert theme.colors.pre_background == "#1f2937"
    end

    test "returns :error for unknown preset" do
      assert Presets.get("nonexistent") == :error
    end
  end
end