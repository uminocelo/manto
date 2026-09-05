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
      assert theme.colors.primary.text == "#1f2937"
      assert theme.colors.primary.background == "#ffffff"
      assert theme.colors.secondary.text == "#4b5563"
      assert theme.colors.secondary.background == "#f3f4f6"
      assert theme.colors.accent.text == "#4f46e5"
      assert theme.colors.accent.background == "#eef2ff"

      assert theme.typography.font_body ==
               "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"

      assert theme.typography.font_code == "ui-monospace, monospace"
      assert theme.layout.page_width == "42rem"
      assert theme.layout.content_radius == "0.375rem"
    end

    test "returns the dark preset" do
      assert {:ok, %Theme{} = theme} = Presets.get("dark")
      assert theme.colors.primary.text == "#e5e7eb"
      assert theme.colors.primary.background == "#111827"
      assert theme.colors.secondary.text == "#9ca3af"
      assert theme.colors.secondary.background == "#1f2937"
      assert theme.colors.accent.text == "#818cf8"
      assert theme.colors.accent.background == "#312e81"
    end

    test "returns :error for unknown preset" do
      assert Presets.get("nonexistent") == :error
    end
  end
end
