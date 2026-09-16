defmodule MantoWeb.SettingsLive do
  use MantoWeb, :live_view
  alias Manto.Content
  alias Manto.Fabric
  alias Manto.Plugin
  alias Manto.Site

  @editable_fields ~w(title description base_url vault_path)

  def mount(_params, _session, socket) do
    {:ok, assign_vault(socket, Site.config()) |> assign(current_path: "")}
  end

  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, current_path: URI.parse(uri).path)}
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
        {:noreply,
         socket |> assign(builder_from_theme(name, theme)) |> assign(builder_flash: nil)}

      :error ->
        {:noreply, assign(socket, builder_flash: "Theme '#{name}' not found")}
    end
  end

  def handle_event("builder-change", params, socket) do
    target = params |> Map.get("_target", [""]) |> List.first()

    value =
      if target != "",
        do: Map.get(params, target, Map.get(params, "value")),
        else: Map.get(params, "value")

    socket =
      case target do
        "builder-name" ->
          assign_builder_field(socket, "builder_name", value)

        "builder-primary-text" ->
          assign_builder_field(socket, "builder_colors", :primary, :text, value)

        "builder-primary-bg" ->
          assign_builder_field(socket, "builder_colors", :primary, :background, value)

        "builder-secondary-text" ->
          assign_builder_field(socket, "builder_colors", :secondary, :text, value)

        "builder-secondary-bg" ->
          assign_builder_field(socket, "builder_colors", :secondary, :background, value)

        "builder-accent-text" ->
          assign_builder_field(socket, "builder_colors", :accent, :text, value)

        "builder-accent-bg" ->
          assign_builder_field(socket, "builder_colors", :accent, :background, value)

        "builder-font-heading" ->
          assign_builder_field(socket, "builder_typography", :font_heading, value)

        "builder-font-body" ->
          assign_builder_field(socket, "builder_typography", :font_body, value)

        "builder-font-code" ->
          assign_builder_field(socket, "builder_typography", :font_code, value)

        "builder-page-width" ->
          assign_builder_field(socket, "builder_layout", :page_width, value)

        "builder-content-radius" ->
          assign_builder_field(socket, "builder_layout", :content_radius, value)

        "builder-custom-css" ->
          assign_builder_field(socket, "builder_custom_css", value)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("save-theme", _, socket) do
    name = socket.assigns.builder_name

    if is_nil(name) or String.trim(name) == "" do
      {:noreply, assign(socket, builder_flash: "Please enter a theme name")}
    else
      tokens = %{
        "colors" => %{
          "primary" => %{
            "text" => socket.assigns.builder_colors[:primary][:text],
            "background" => socket.assigns.builder_colors[:primary][:background]
          },
          "secondary" => %{
            "text" => socket.assigns.builder_colors[:secondary][:text],
            "background" => socket.assigns.builder_colors[:secondary][:background]
          },
          "accent" => %{
            "text" => socket.assigns.builder_colors[:accent][:text],
            "background" => socket.assigns.builder_colors[:accent][:background]
          }
        },
        "typography" => %{
          "font_heading" => socket.assigns.builder_typography[:font_heading],
          "font_body" => socket.assigns.builder_typography[:font_body],
          "font_code" => socket.assigns.builder_typography[:font_code]
        },
        "layout" => %{
          "page_width" => socket.assigns.builder_layout[:page_width],
          "content_radius" => socket.assigns.builder_layout[:content_radius]
        },
        "custom_css" => socket.assigns.builder_custom_css
      }

      Fabric.save_theme(name, tokens)

      case Fabric.Theme.new(tokens) do
        %Manto.Fabric.Theme{} = theme ->
          {:noreply,
           socket
           |> assign_vault(Site.config())
           |> assign(builder_from_theme(name, theme))
           |> assign(builder_flash: "Theme '#{name}' saved")}

        {:error, reason} ->
          {:noreply, assign(socket, builder_flash: reason)}
      end
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
          "primary" => %{
            "text" => socket.assigns.builder_colors[:primary][:text],
            "background" => socket.assigns.builder_colors[:primary][:background]
          },
          "secondary" => %{
            "text" => socket.assigns.builder_colors[:secondary][:text],
            "background" => socket.assigns.builder_colors[:secondary][:background]
          },
          "accent" => %{
            "text" => socket.assigns.builder_colors[:accent][:text],
            "background" => socket.assigns.builder_colors[:accent][:background]
          }
        },
        "typography" => %{
          "font_heading" => socket.assigns.builder_typography[:font_heading],
          "font_body" => socket.assigns.builder_typography[:font_body],
          "font_code" => socket.assigns.builder_typography[:font_code]
        },
        "layout" => %{
          "page_width" => socket.assigns.builder_layout[:page_width],
          "content_radius" => socket.assigns.builder_layout[:content_radius]
        },
        "custom_css" => socket.assigns.builder_custom_css
      }

      Fabric.save_theme(dup_name, tokens)

      case Fabric.Theme.new(tokens) do
        %Manto.Fabric.Theme{} = theme ->
          {:noreply,
           socket
           |> assign_vault(Site.config())
           |> assign(builder_from_theme(dup_name, theme))
           |> assign(builder_flash: "Duplicated as '#{dup_name}'")}

        {:error, reason} ->
          {:noreply, assign(socket, builder_flash: reason)}
      end
    end
  end

  def handle_event("delete-theme", params, socket) do
    name = params["name"] || socket.assigns.builder_name

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
    |> assign_new(:builder_custom_css, fn -> "" end)
  end

  defp builder_defaults(name) do
    %{
      editing_theme: name,
      builder_name: name,
      builder_colors: default_builder_colors(),
      builder_typography: default_builder_typography(),
      builder_layout: default_builder_layout(),
      builder_custom_css: ""
    }
  end

  defp builder_from_theme(name, theme) do
    %{
      editing_theme: name,
      builder_name: name,
      builder_colors: %{
        primary: %{
          text: theme.colors.primary.text,
          background: theme.colors.primary.background
        },
        secondary: %{
          text: theme.colors.secondary.text,
          background: theme.colors.secondary.background
        },
        accent: %{
          text: theme.colors.accent.text,
          background: theme.colors.accent.background
        }
      },
      builder_typography: %{
        font_heading: theme.typography.font_heading,
        font_body: theme.typography.font_body,
        font_code: theme.typography.font_code
      },
      builder_layout: %{
        page_width: theme.layout.page_width,
        content_radius: theme.layout.content_radius
      },
      builder_custom_css: theme.custom_css
    }
  end

  defp default_builder_colors do
    %{
      primary: %{text: "#1f2937", background: "#ffffff"},
      secondary: %{text: "#4b5563", background: "#f3f4f6"},
      accent: %{text: "#4f46e5", background: "#eef2ff"}
    }
  end

  defp default_builder_typography do
    %{
      font_heading: "inherit",
      font_body: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif",
      font_code: "ui-monospace, monospace"
    }
  end

  defp default_builder_layout do
    %{page_width: "42rem", content_radius: "0.375rem"}
  end

  defp assign_builder_field(socket, key, value) do
    assign(socket, String.to_atom(key), value)
  end

  defp assign_builder_field(socket, group_key, sub_key, value) do
    current = Map.get(socket.assigns, String.to_atom(group_key), %{})
    updated = Map.put(current, sub_key, value)
    assign(socket, String.to_atom(group_key), updated)
  end

  defp assign_builder_field(socket, group_key, sub_key, sub_sub_key, value) do
    current = Map.get(socket.assigns, String.to_atom(group_key), %{})
    inner = Map.get(current, sub_key, %{})
    updated_inner = Map.put(inner, sub_sub_key, value)
    updated = Map.put(current, sub_key, updated_inner)
    assign(socket, String.to_atom(group_key), updated)
  end
end
