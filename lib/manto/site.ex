defmodule Manto.Site do
  @moduledoc """
  Site-level configuration for the static site build.

  Config is resolved in order of precedence: a `manto.json` file in the project
  root (overridable via `:path`) wins over `config/` entries in the `:manto`
  application env, which win over built-in defaults.

  Supported keys: `title`, `description`, `base_url` (used by `rss.xml` and
  `sitemap.xml`).
  """

  @defaults %{
    "title" => "Manto",
    "description" => "A local-first Markdown site",
    "base_url" => ""
  }

  @doc """
  Return the effective site config as a string-keyed map.
  """
  @spec config(keyword()) :: map()
  def config(opts \\ []) do
    path = Keyword.get(opts, :path, "manto.json")

    file_config = if File.exists?(path), do: decode_json!(path), else: %{}

    app_config =
      :manto
      |> Application.get_env(:site, %{})
      |> Map.new(fn {key, value} -> {to_string(key), value} end)

    @defaults |> Map.merge(app_config) |> Map.merge(file_config)
  end

  defp decode_json!(path) do
    case path |> File.read!() |> Jason.decode() do
      {:ok, config} when is_map(config) -> config
      _ -> raise ArgumentError, "Invalid #{path}: expected a JSON object"
    end
  end
end
