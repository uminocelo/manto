defmodule Manto.Site do
  @moduledoc """
  Site-level configuration for the static site build and the editor vault.

  Config is resolved in order of precedence: a `manto.json` file in the project
  root (overridable via `:path`) wins over `config/` entries in the `:manto`
  application env, which win over built-in defaults.

  Supported keys: `title`, `description`, `base_url` (used by `rss.xml` and
  `sitemap.xml`) and `vault_path` (the folder holding the Markdown content,
  relative to the project root).
  """

  @defaults %{
    "title" => "Manto",
    "description" => "A local-first Markdown site",
    "base_url" => "",
    "vault_path" => "priv/content",
    "plugins" => []
  }

  @doc """
  Path to the `manto.json` config file.

  Defaults to `manto.json` in the working directory. Can be overridden via the
  `:config_path` application env (used by tests to isolate writes).
  """
  @spec config_path() :: String.t()
  def config_path do
    Application.get_env(:manto, :config_path, "manto.json")
  end

  @doc """
  Return the effective site config as a string-keyed map.
  """
  @spec config(keyword()) :: map()
  def config(opts \\ []) do
    path = Keyword.get(opts, :path, config_path())

    file_config = if File.exists?(path), do: decode_json!(path), else: %{}

    app_config =
      :manto
      |> Application.get_env(:site, %{})
      |> Map.new(fn {key, value} -> {to_string(key), value} end)

    @defaults |> Map.merge(app_config) |> Map.merge(file_config)
  end

  @doc """
  Persist settings to the config file, merging with any keys already present.

  Returns `:ok`.
  """
  @spec save(map(), keyword()) :: :ok
  def save(settings, opts \\ []) do
    path = Keyword.get(opts, :path, config_path())
    current = if File.exists?(path), do: decode_json!(path), else: %{}
    merged = Map.merge(current, settings)
    File.write!(path, Jason.encode!(merged, pretty: true) <> "\n")
  end

  defp decode_json!(path) do
    case path |> File.read!() |> Jason.decode() do
      {:ok, config} when is_map(config) -> config
      _ -> raise ArgumentError, "Invalid #{path}: expected a JSON object"
    end
  end
end
