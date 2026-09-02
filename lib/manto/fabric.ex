defmodule Manto.Fabric do
  @moduledoc """
  CSS generation from Fabric design tokens and CRUD for custom themes.

  `render_css/1` compiles a `Manto.Fabric.Theme` into a complete CSS string
  with a `:root` variable block and a base template referencing those vars.

  `list_themes/0`, `get_theme/1`, `save_theme/2`, `delete_theme/1`, and
  `set_active/1` manage custom themes persisted under the `"fabric"` key in
  `manto.json`.
  """

  alias Manto.Fabric.Theme
  alias Manto.Fabric.Presets
  alias Manto.Site

  @base_template """
  body {
    max-width: var(--fabric-content-width);
    margin: 2rem auto;
    padding: 0 1rem;
    font-family: var(--fabric-font-body);
    color: var(--fabric-color-text);
    background: var(--fabric-color-bg);
    line-height: 1.6;
  }

  nav {
    margin-bottom: 2rem;
    font-size: 0.875rem;
  }

  nav a {
    margin-right: 1rem;
  }

  a {
    color: var(--fabric-color-link);
  }

  pre {
    background: var(--fabric-color-pre-bg);
    padding: 1rem;
    overflow-x: auto;
    border-radius: var(--fabric-content-radius);
  }

  code {
    font-family: var(--fabric-font-code);
  }
  """

  @doc """
  Compile a `Theme` struct into a CSS string.

  The output starts with a `:root { ... }` block declaring the design tokens
  as CSS custom properties, followed by the base template which references
  those variables.

  ## Examples

      iex> theme = Manto.Fabric.Theme.new(%{})
      iex> css = Manto.Fabric.render_css(theme)
      iex> String.starts_with?(css, ":root {")
      true
  """
  @spec render_css(Theme.t()) :: String.t()
  def render_css(%Theme{} = theme) do
    root_block(theme) <> "\n" <> @base_template
  end

  @doc """
  List all available themes — built-in presets and custom themes.

  Each entry is a map with `:name`, `:type` (`:builtin` or `:custom`), and
  for custom themes a `:theme` key with the `%Theme{}` struct.
  """
  @spec list_themes() :: [map()]
  def list_themes do
    builtins =
      Enum.map(Presets.list(), fn name ->
        {:ok, theme} = Presets.get(name)
        %{name: name, type: :builtin, theme: theme}
      end)

    customs =
      Enum.map(custom_themes(), fn {name, tokens} ->
        %{name: name, type: :custom, theme: Theme.new(tokens)}
      end)

    builtins ++ customs
  end

  @doc """
  Get a theme by name — checks built-in presets first, then custom themes.

  Returns `{:ok, %Theme{}}` or `:error`.
  """
  @spec get_theme(String.t()) :: {:ok, Theme.t()} | :error
  def get_theme(name) when is_binary(name) do
    case Presets.get(name) do
      {:ok, _} = ok ->
        ok

      :error ->
        case Map.fetch(custom_themes(), name) do
          {:ok, tokens} -> {:ok, Theme.new(tokens)}
          :error -> :error
        end
    end
  end

  @doc """
  Save a custom theme under the given name.

  Merges the token map into the `fabric.themes` key of `manto.json`.
  Returns `:ok`.
  """
  @spec save_theme(String.t(), map()) :: :ok
  def save_theme(name, tokens) when is_binary(name) and is_map(tokens) do
    current = Site.config()
    fabric = Map.get(current, "fabric", %{"active" => "default", "themes" => %{}})
    themes = Map.put(fabric["themes"], name, tokens)
    updated_fabric = Map.put(fabric, "themes", themes)
    Site.save(%{"fabric" => updated_fabric})
  end

  @doc """
  Delete a custom theme.

  Returns `{:error, :builtin}` if the name matches a built-in preset.
  Returns `{:error, :active}` if the theme is currently active.
  Returns `:ok` on success.
  """
  @spec delete_theme(String.t()) :: :ok | {:error, :builtin | :active}
  def delete_theme(name) when is_binary(name) do
    case Presets.get(name) do
      {:ok, _} ->
        {:error, :builtin}

      :error ->
        current = Site.config()
        fabric = Map.get(current, "fabric", %{"active" => "default", "themes" => %{}})

        if fabric["active"] == name do
          {:error, :active}
        else
          themes = Map.delete(fabric["themes"], name)
          updated_fabric = Map.put(fabric, "themes", themes)
          Site.save(%{"fabric" => updated_fabric})
          :ok
        end
    end
  end

  @doc """
  Set the active theme by name.

  Returns `:ok` after persisting the change.
  """
  @spec set_active(String.t()) :: :ok
  def set_active(name) when is_binary(name) do
    current = Site.config()
    fabric = Map.get(current, "fabric", %{"active" => "default", "themes" => %{}})
    updated_fabric = Map.put(fabric, "active", name)
    Site.save(%{"fabric" => updated_fabric})
  end

  @doc """
  Return the active theme as a `%Theme{}` struct.
  """
  @spec active_theme() :: Theme.t()
  def active_theme do
    current = Site.config()
    fabric = Map.get(current, "fabric", %{"active" => "default", "themes" => %{}})
    {:ok, theme} = get_theme(fabric["active"])
    theme
  end

  defp custom_themes do
    current = Site.config()
    fabric = Map.get(current, "fabric", %{"active" => "default", "themes" => %{}})
    Map.get(fabric, "themes", %{})
  end

  defp root_block(theme) do
    vars = [
      "  --fabric-color-text: #{theme.colors.text};",
      "  --fabric-color-bg: #{theme.colors.background};",
      "  --fabric-color-link: #{theme.colors.link};",
      "  --fabric-color-pre-bg: #{theme.colors.pre_background};",
      "  --fabric-font-body: #{theme.typography.font_body};",
      "  --fabric-font-code: #{theme.typography.font_code};",
      "  --fabric-content-width: #{theme.layout.content_width};",
      "  --fabric-content-radius: #{theme.layout.content_radius};"
    ]

    ":root {\n" <> Enum.join(vars, "\n") <> "\n}\n"
  end
end
