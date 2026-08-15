defmodule MantoWeb.SettingsLive do
  use MantoWeb, :live_view
  alias Manto.Content
  alias Manto.Site

  @editable_fields ~w(title description base_url vault_path)

  def mount(_params, _session, socket) do
    {:ok, assign_vault(socket, Site.config())}
  end

  def handle_event("save", params, socket) do
    case build_settings(params) do
      {:ok, settings} ->
        Site.save(settings)
        File.mkdir_p!(Path.expand(settings["vault_path"]))

        socket =
          socket
          |> put_flash(:info, "Settings saved.")
          |> assign_vault(Site.config())

        {:noreply, socket}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  defp build_settings(params) do
    settings =
      params
      |> Map.take(@editable_fields)
      |> Map.new(fn {key, value} -> {key, String.trim(value || "")} end)
      |> maybe_default("title", Site.config()["title"])
      |> maybe_default("vault_path", Site.config()["vault_path"])

    case validate_vault_path(settings["vault_path"]) do
      :ok -> {:ok, settings}
      {:error, message} -> {:error, message}
    end
  end

  defp maybe_default(settings, key, default) do
    if settings[key] in [nil, ""], do: Map.put(settings, key, default), else: settings
  end

  defp validate_vault_path(path) do
    expanded = Path.expand(path)

    if File.exists?(expanded) and not File.dir?(expanded) do
      {:error, "\"#{path}\" exists but is not a directory."}
    else
      :ok
    end
  end

  defp assign_vault(socket, config) do
    assign(socket,
      title: config["title"],
      description: config["description"],
      base_url: config["base_url"],
      vault_path: config["vault_path"],
      vault_abs_path: Path.expand(config["vault_path"]),
      page_count: length(Content.list_pages())
    )
  end
end
