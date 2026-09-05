defmodule Manto.Fabric.Theme do
  @moduledoc """
  A design-token struct representing a Fabric theme.

  Tokens follow the 60/30/10 colour rule, cover typography and layout, and
  support an optional custom CSS file. All fields have sensible defaults. Pass
  a map of overrides to `new/1` to customise — colour values are validated as
  hex strings.
  """

  @hex_regex ~r/^#[0-9a-fA-F]{6}$/

  @type hex_color :: String.t()

  @type t :: %__MODULE__{
          colors: %{
            primary: %{text: hex_color(), background: hex_color()},
            secondary: %{text: hex_color(), background: hex_color()},
            accent: %{text: hex_color(), background: hex_color()}
          },
          typography: %{
            font_heading: String.t(),
            font_body: String.t(),
            font_code: String.t()
          },
          layout: %{
            page_width: String.t(),
            content_radius: String.t()
          },
          custom_css: String.t()
        }

  defstruct colors: %{
              primary: %{text: "#1f2937", background: "#ffffff"},
              secondary: %{text: "#4b5563", background: "#f3f4f6"},
              accent: %{text: "#4f46e5", background: "#eef2ff"}
            },
            typography: %{
              font_heading: "inherit",
              font_body: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif",
              font_code: "ui-monospace, monospace"
            },
            layout: %{
              page_width: "42rem",
              content_radius: "0.375rem"
            },
            custom_css: ""

  @doc """
  Build a `Theme` struct, merging `overrides` over the defaults.

  Accepts a flat map with string keys (`"colors"`, `"typography"`, `"layout"`,
  `"custom_css"`) whose values are maps of the same shape. Returns `{:error, reason}`
  when a colour value is not a valid six-digit hex string.

  ## Examples

      iex> Theme.new(%{})
      %Theme{...}

      iex> Theme.new(%{"colors" => %{"primary" => %{"background" => "#ff0000"}}})
      %Theme{colors: %{primary: %{background: "#ff0000", ...}, ...}}

      iex> Theme.new(%{"colors" => %{"primary" => %{"background" => "blue"}}})
      {:error, "Invalid hex colour: blue for key background"}
  """
  @spec new(map()) :: t() | {:error, String.t()}
  def new(overrides) when is_map(overrides) do
    merged = merge_deep(%__MODULE__{}, overrides)

    case validate_hexes(merged) do
      :ok -> merged
      {:error, _} = err -> err
    end
  end

  defp merge_deep(%__MODULE__{} = struct, overrides) do
    struct
    |> Map.from_struct()
    |> do_merge(overrides |> string_keys_to_atoms() |> prune_unknown(struct))
    |> then(fn map -> struct!(__MODULE__, map) end)
  end

  # Convert string keys to atoms, recursing into nested maps.
  # Uses String.to_atom/1 (safe here — keys come from a limited known set).
  defp string_keys_to_atoms(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      converted = if is_binary(key), do: String.to_atom(key), else: key
      {converted, string_keys_to_atoms(value)}
    end)
  end

  defp string_keys_to_atoms(value), do: value

  # Remove keys from the override map that don't exist in the struct,
  # so that old saved themes (with legacy keys like `:text`) don't cause
  # struct! to raise. Recurses into nested maps.
  defp prune_unknown(overrides, template) do
    template_map = if is_struct(template), do: Map.from_struct(template), else: template

    overrides
    |> Map.take(Map.keys(template_map))
    |> Map.new(fn {key, value} ->
      if is_map(value) and is_map(template_map[key]) do
        {key, prune_unknown(value, template_map[key])}
      else
        {key, value}
      end
    end)
  end

  defp do_merge(target, overrides) when is_map(overrides) do
    Map.merge(target, overrides, fn _key, default, override ->
      if is_map(default) and is_map(override) and not Map.has_key?(override, :__struct__) do
        do_merge(default, override)
      else
        override
      end
    end)
  end

  defp validate_hexes(%__MODULE__{} = theme) do
    all_colors = flatten_color_values(theme.colors)

    invalid =
      Enum.reject(all_colors, fn {_key, value} -> String.match?(value, @hex_regex) end)

    case invalid do
      [] ->
        :ok

      [{key, value} | _] ->
        {:error, "Invalid hex colour: #{value} for key #{key}"}
    end
  end

  defp flatten_color_values(map) when is_map(map) do
    Enum.flat_map(map, fn {key, value} ->
      if is_map(value), do: flatten_color_values(value), else: [{key, value}]
    end)
  end
end
