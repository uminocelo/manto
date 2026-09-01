defmodule MantoWeb.SettingsLive do
  use MantoWeb, :live_view
  alias Manto.Content
  alias Manto.Fabric
  alias Manto.Plugin
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

  def handle_event("toggle-theme-builder", _, socket) do
    {:noreply, update(socket, :show_theme_builder, &(!&1))}
  end

  def handle_event("new-theme", _, socket) do
    {:noreply, socket |> assign(builder_defaults(nil)) |> assign(builder_flash: nil)}
  end

  def handle_event("edit-theme", %{"name" => name}, socket) do
    case Fabric.get_theme(name) do
      {:ok, theme} ->
        {:noreply, socket |> assign(builder_from_theme(name, theme)) |> assign(builder_flash: nil)}

      :error ->
        {:noreply, assign(socket, builder_flash: "Theme '#{name}' not found")}
    end
  end

  def handle_event("builder-change", params, socket) do
    builder_name = Map.get(params, "_target", [""]) |> List.first() |> normalize_builder_key()

    socket =
      socket
      |> assign_builder_field("builder_name", Map.get(params, "value", socket.assigns.builder_name))
      |> assign_builder_field("builder_colors", :text, Map.get(params, "builder-color-text", socket.assigns.builder_colors[:text]))
      |> assign_builder_field("builder_colors", :background, Map.get(params, "builder-color-bg", socket.assigns.builder_colors[:background]))
      |> assign_builder_field("builder_colors", :link, Map.get(params, "builder-color-link", socket.assigns.builder_colors[:link]))
      |> assign_builder_field("builder_colors", :pre_background, Map.get(params, "builder-color-pre-bg", socket.assigns.builder_colors[:pre_background]))
      |> assign_builder_field("builder_typography", :font_body, Map.get(params, "builder-font-body", socket.assigns.builder_typography[:font_body]))
      |> assign_builder_field("builder_typography", :font_code, Map.get(params, "builder-font-code", socket.assigns.builder_typography[:font_code]))
      |> assign_builder_field("builder_layout", :content_width, Map.get(params, "builder-content-width", socket.assigns.builder_layout[:content_width]))

    {:noreply, socket}
  end

  def handle_event("save-theme", _, socket) do
    name = socket.assigns.builder_name

    if is_nil(name) or String.trim(name) == "" do
      {:noreply, assign(socket, builder_flash: "Please enter a theme name")}
    else
      tokens = %{
        "colors" => %{
          "text" => socket.assigns.builder_colors[:text],
          "background" => socket.assigns.builder_colors[:background],
          "link" => socket.assigns.builder_colors[:link],
          "pre_background" => socket.assigns.builder_colors[:pre_background]
        },
        "typography" => %{
          "font_body" => socket.assigns.builder_typography[:font_body],
          "font_code" => socket.assigns.builder_typography[:font_code]
        },
        "layout" => %{
          "content_width" => socket.assigns.builder_layout[:content_width],
          "content_radius" => socket.assigns.builder_layout[:content_radius]
        }
      }

      Fabric.save_theme(name, tokens)

      {:noreply,
       socket
       |> assign_vault(Site.config())
       |> assign(builder_from_theme(name, Fabric.Theme.new(tokens)))
       |> assign(builder_flash: "Theme '#{name}' saved")}
    end
  end

  def handle_event("duplicate-theme", _, socket) do
    name = socket.assigns.builder_name

    if is_nil(name) or String.trim(name) == "" do
      {:noreply, assign(socket, builder_flash: "Save the current theme first before duplicating")}
    else
      {new_name, _} = name |> String.trim() |> String.split_at(40)
      dup_name = new_name <> "-copy"

      tokens = %{
        "colors" => %{
          "text" => socket.assigns.builder_colors[:text],
          "background" => socket.assigns.builder_colors[:background],
          "link" => socket.assigns.builder_colors[:link],
          "pre_background" => socket.assigns.builder_colors[:pre_background]
        },
        "typography" => %{
          "font_body" => socket.assigns.builder_typography[:font_body],
          "font_code" => socket.assigns.builder_typography[:font_code]
        },
        "layout" => %{
          "content_width" => socket.assigns.builder_layout[:content_width],
          "content_radius" => socket.assigns.builder_layout[:content_radius]
        }
      }

      Fabric.save_theme(dup_name, tokens)

      {:noreply,
       socket
       |> assign_vault(Site.config())
       |> assign(builder_from_theme(dup_name, Fabric.Theme.new(tokens)))
       |> assign(builder_flash: "Duplicated as '#{dup_name}'")}
    end
  end

  def handle_event("delete-theme", _, socket) do
    name = socket.assigns.builder_name

    if is_nil(name) or String.trim(name) == "" do
      {:noreply, assign(socket, builder_flash: "No theme selected to delete")}
    else
      case Fabric.delete_theme(name) do
        :ok ->
          {:noreply,
           socket
           |> assign_vault(Site.config())
           |> assign(builder_defaults(nil))
           |> assign(builder_flash: "Theme '#{name}' deleted")}

        {:error, :builtin} ->
          {:noreply, assign(socket, builder_flash: "Cannot delete built-in theme '#{name}'")}

        {:error, :active} ->
          {:noreply, assign(socket, builder_flash: "Cannot delete active theme '#{name}'")}
      end
    end
  end

  defp build_settings(params) do
    settings =
      params
      |> Map.take(@editable_fields)
      |> Map.new(fn {key, value} -> {key, String.trim(value || "")} end)
      |> maybe_default("title", Site.config()["title"])
      |> maybe_default("vault_path", Site.config()["vault_path"])

    plugins =
      params
      |> Map.get("plugins", [])
      |> List.wrap()
      |> Enum.reject(&(&1 == ""))

    theme = Map.get(params, "theme", "default")
    current_fabric = Site.config() |> Map.get("fabric", %{"active" => "default", "themes" => %{}})
    fabric = Map.put(current_fabric, "active", theme)

    case validate_vault_path(settings["vault_path"]) do
      :ok ->
        {:ok, settings |> Map.put("plugins", plugins) |> Map.put("fabric", fabric)}

      {:error, message} ->
        {:error, message}
    end
  end

  defp maybe_default(settings, key, default) do
    if settings[key] in [nil, ""], do: Map.put(settings, key, default), else: settings
  end

  defp validate_vault_path(path) do
    expanded = Path.expand(path)

    cond do
      String.starts_with?(path, "~") and String.contains?(expanded, "~") ->
        {:error,
         "Could not expand \"#{path}\": a leading \"~\" must be written as \"~/\" (your " <>
           "home directory) or \"~user/\" (another user's home). Otherwise use an absolute " <>
           "path such as \"/Users/name/Documents/vault\"."}

      File.exists?(expanded) and not File.dir?(expanded) ->
        {:error, "\"#{path}\" exists but is not a directory."}

      true ->
        :ok
    end
  end

  defp assign_vault(socket, config) do
    fabric = Map.get(config, "fabric", %{"active" => "default", "themes" => %{}})

    socket
    |> assign(
      title: config["title"],
      description: config["description"],
      base_url: config["base_url"],
      vault_path: config["vault_path"],
      vault_abs_path: Path.expand(config["vault_path"]),
      page_count: length(Content.list_pages()),
      available_plugins: Plugin.available_plugins(),
      plugins: config["plugins"] || [],
      available_themes: Fabric.list_themes(),
      active_theme: fabric["active"]
    )
    |> assign_new(:show_theme_builder, fn -> false end)
    |> assign_new(:builder_flash, fn -> nil end)
    |> assign_new(:editing_theme, fn -> nil end)
    |> assign_new(:builder_name, fn -> nil end)
    |> assign_new(:builder_colors, fn -> default_builder_colors() end)
    |> assign_new(:builder_typography, fn -> default_builder_typography() end)
    |> assign_new(:builder_layout, fn -> default_builder_layout() end)
  end

  defp builder_defaults(name) do
    %{
      editing_theme: name,
      builder_name: name,
      builder_colors: default_builder_colors(),
      builder_typography: default_builder_typography(),
      builder_layout: default_builder_layout()
    }
  end

  defp builder_from_theme(name, theme) do
    %{
      editing_theme: name,
      builder_name: name,
      builder_colors: %{
        text: theme.colors.text,
        background: theme.colors.background,
        link: theme.colors.link,
        pre_background: theme.colors.pre_background
      },
      builder_typography: %{
        font_body: theme.typography.font_body,
        font_code: theme.typography.font_code
      },
      builder_layout: %{
        content_width: theme.layout.content_width,
        content_radius: theme.layout.content_radius
      }
    }
  end

  defp default_builder_colors do
    %{text: "#1f2937", background: "#ffffff", link: "#4f46e5", pre_background: "#f3f4f6"}
  end

  defp default_builder_typography do
    %{font_body: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif", font_code: "ui-monospace, monospace"}
  end

  defp default_builder_layout do
    %{content_width: "42rem", content_radius: "0.375rem"}
  end

  defp assign_builder_field(socket, key, value) do
    assign(socket, String.to_atom(key), value)
  end

  defp assign_builder_field(socket, group_key, sub_key, value) do
    current = Map.get(socket.assigns, String.to_atom(group_key), %{})
    updated = Map.put(current, sub_key, value)
    assign(socket, String.to_atom(group_key), updated)
  end

  defp normalize_builder_key("builder-name"), do: "builder_name"
  defp normalize_builder_key("builder-content-width"), do: "builder_content_width"
  defp normalize_builder_key("builder-font-body"), do: "builder_font_body"
  defp normalize_builder_key("builder-font-code"), do: "builder_font_code"
  defp normalize_builder_key(_), do: nil
end