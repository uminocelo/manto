defmodule Manto.Fabric.Theme do
  @moduledoc """
  A design-token struct representing a Fabric theme.

  Tokens cover colours, typography, and layout. All fields have sensible
  defaults (matching the original `default.css`). Pass a map of overrides
  to `new/1` to customise — colour values are validated as hex strings.
  """

  @hex_regex ~r/^#[0-9a-fA-F]{6}$/

  @type hex_color :: String.t()

  @type t :: %__MODULE__{
          colors: %{
            text: hex_color(),
            background: hex_color(),
            link: hex_color(),
            pre_background: hex_color()
          },
          typography: %{
            font_body: String.t(),
            font_code: String.t()
          },
          layout: %{
            content_width: String.t(),
            content_radius: String.t()
          }
        }

  defstruct colors: %{
              text: "#1f2937",
              background: "#ffffff",
              link: "#4f46e5",
              pre_background: "#f3f4f6"
            },
            typography: %{
              font_body: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif",
              font_code: "ui-monospace, monospace"
            },
            layout: %{
              content_width: "42rem",
              content_radius: "0.375rem"
            }

  @doc """
  Build a `Theme` struct, merging `overrides` over the defaults.

  Accepts a flat map with string keys (`"colors"`, `"typography"`, `"layout"`)
  whose values are maps of the same shape. Returns `{:error, reason}` when a
  colour value is not a valid six-digit hex string.

  ## Examples

      iex> Theme.new(%{})
      %Theme{...}

      iex> Theme.new(%{"colors" => %{"background" => "#ff0000"}})
      %Theme{colors: %{background: "#ff0000", ...}}

      iex> Theme.new(%{"colors" => %{"background" => "blue"}})
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
    |> do_merge(string_keys_to_atoms(overrides))
    |> then(fn map -> struct!(__MODULE__, map) end)
  end

  defp string_keys_to_atoms(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      converted =
        if is_binary(key) do
          String.to_existing_atom(key)
        else
          key
        end

      {converted, string_keys_to_atoms(value)}
    end)
  end

  defp string_keys_to_atoms(value), do: value

  defp do_merge(target, overrides) when is_map(overrides) do
    Map.merge(target, overrides, fn _key, default, override ->
      if is_map(default) and is_map(override) and not Map.has_key?(override, :__struct__) do
        Map.merge(default, override, fn _k, _dv, ov -> ov end)
      else
        override
      end
    end)
  end

  defp validate_hexes(%__MODULE__{} = theme) do
    invalid =
      theme.colors
      |> Enum.reject(fn {_key, value} -> String.match?(value, @hex_regex) end)

    case invalid do
      [] ->
        :ok

      [{key, value} | _] ->
        {:error, "Invalid hex colour: #{value} for key #{key}"}
    end
  end
end
