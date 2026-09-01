defmodule Manto.Fabric.Presets do
  @moduledoc """
  Built-in Fabric theme presets.

  `get/1` returns a `Manto.Fabric.Theme` struct for the named preset.
  `list/0` returns all available preset names.
  """

  @default %Manto.Fabric.Theme{}

  @dark Manto.Fabric.Theme.new(%{
          "colors" => %{
            "text" => "#e5e7eb",
            "background" => "#111827",
            "link" => "#818cf8",
            "pre_background" => "#1f2937"
          }
        })

  @presets %{"default" => @default, "dark" => @dark}

  @doc """
  Return the named preset theme.

  Returns `{:ok, %Theme{}}` or `:error`.
  """
  @spec get(String.t()) :: {:ok, Manto.Fabric.Theme.t()} | :error
  def get(name) when is_binary(name) do
    case Map.fetch(@presets, name) do
      {:ok, theme} -> {:ok, theme}
      :error -> :error
    end
  end

  @doc """
  Return all available preset names.
  """
  @spec list() :: [String.t()]
  def list do
    Map.keys(@presets)
  end
end