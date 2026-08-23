defmodule MantoWeb.EditorLive do
  use MantoWeb, :live_view
  alias Manto.Content
  alias Manto.Content.Parser

  def mount(_params, _session, socket) do
    pages = Content.list_pages()

    {:ok,
     assign(socket,
       pages: pages,
       page_entries: page_entries(pages),
       page_titles: Content.list_titles(),
       draft_pages: Content.list_draft_pages(),
       collapsed_folders: MapSet.new(),
       filter: ""
     )}
  end

  def handle_params(%{"page" => page}, _uri, socket) when is_list(page) do
    page = Enum.join(page, "/")
    {:noreply, open_page(socket, page)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, open_page(socket, "welcome")}
  end

  defp open_page(socket, page) do
    page = if Content.valid_page_name?(page), do: page, else: "welcome"
    existing_body = Content.get_page(page)
    body = existing_body || "# #{Path.basename(page)}"
    # checks if the page exists already
    load_page(socket, page, body, new: is_nil(existing_body))
  end

  def handle_event("filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, filter: filter)}
  end

  def handle_event("toggle_folder", %{"folder" => folder}, socket) do
    collapsed =
      if MapSet.member?(socket.assigns.collapsed_folders, folder),
        do: MapSet.delete(socket.assigns.collapsed_folders, folder),
        else: MapSet.put(socket.assigns.collapsed_folders, folder)

    {:noreply, assign(socket, collapsed_folders: collapsed)}
  end

  def handle_event("update", %{"markdown" => body}, socket) do
    # keep the new state on each update, until a save event
    {:noreply,
     load_page(socket, socket.assigns.page, body, saved: false, new: socket.assigns.new)}
  end

  def handle_event("save", _params, socket) do
    Content.save_page(socket.assigns.page, socket.assigns.body)
    pages = Content.list_pages()

    socket =
      socket
      |> assign(
        saved: true,
        new: false,
        # saves and set new to false
        pages: pages,
        page_entries: page_entries(pages),
        draft_pages: Content.list_draft_pages()
      )
      |> put_flash(:info, "\"#{socket.assigns.page}\" saved.")
      |> push_event("draft_saved", %{})

    {:noreply, socket}
  end

  def handle_event("restore_draft", %{"body" => body}, socket) do
    # autosaved draft restored from localStorage by the EditorGuard hook
    {:noreply, load_page(socket, socket.assigns.page, body, new: socket.assigns.new)}
  end

  def handle_event("new_page", %{"name" => name}, socket) do
    case slugify(name) do
      "" ->
        {:noreply, socket}

      # checks if a page already exists before new page creation
      slug ->
        cond do
          slug in socket.assigns.pages ->
            {:noreply, put_flash(socket, :error, "\"#{slug}\" already exists.")}

          not Content.valid_page_name?(slug) ->
            {:noreply, put_flash(socket, :error, "\"#{slug}\" is not a valid page name.")}

          true ->
            socket =
              socket
              |> put_flash(:info, "\"#{slug}\" created.")
              |> push_navigate(to: "/editor/#{slug}")

            {:noreply, socket}
        end
    end
  end

  def handle_event("rename_page", %{"name" => name}, socket) do
    from = socket.assigns.page

    case slugify(name) do
      "" ->
        {:noreply, socket}

      to ->
        cond do
          to == from ->
            {:noreply, put_flash(socket, :error, "New name is the same as the current name.")}

          not Content.valid_page_name?(to) ->
            {:noreply, put_flash(socket, :error, "\"#{to}\" is not a valid page name.")}

          true ->
            case Content.rename_page(from, to) do
              :ok ->
                pages = Content.list_pages()

                socket =
                  socket
                  |> assign(
                    pages: pages,
                    page_entries: page_entries(pages),
                    draft_pages: Content.list_draft_pages()
                  )
                  |> put_flash(:info, "\"#{from}\" renamed to \"#{to}\".")
                  |> push_navigate(to: "/editor/#{to}")

                {:noreply, socket}

              {:error, :already_exists} ->
                {:noreply, put_flash(socket, :error, "\"#{to}\" already exists.")}

              {:error, _reason} ->
                {:noreply, put_flash(socket, :error, "Could not rename \"#{from}\".")}
            end
        end
    end
  end

  def handle_event("delete_page", _params, socket) do
    page = socket.assigns.page

    case Content.delete_page(page) do
      :ok ->
        pages = Content.list_pages()

        socket =
          socket
          |> assign(
            pages: pages,
            page_entries: page_entries(pages),
            draft_pages: Content.list_draft_pages()
          )
          |> put_flash(:info, "\"#{page}\" deleted.")
          |> push_navigate(to: ~p"/editor")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not delete \"#{page}\".")}
    end
  end

  defp slugify(name) do
    name
    |> String.trim()
    |> String.replace(" ", "-")
    |> String.trim("/")
  end

  defp visible_entries(entries, collapsed_folders, filter) do
    if filter == "" do
      # Normal behavior: respect collapse
      Enum.reject(entries, fn {_depth, _kind, label} ->
        Enum.any?(collapsed_folders, fn folder ->
          String.starts_with?(label, folder <> "/")
        end)
      end)
    else
      # Filtering mode: ignore collapse, show matches + ancestors
      filter_lower = String.downcase(filter)

      matches = Enum.filter(entries, fn {_depth, _kind, label} ->
        String.contains?(String.downcase(label), filter_lower) or
          String.contains?(String.downcase(Path.basename(label)), filter_lower)
      end)

      ancestor_labels =
        matches
        |> Enum.flat_map(fn {_depth, _kind, label} -> ancestor_folders(label) end)
        |> MapSet.new()

      Enum.filter(entries, fn {_depth, _kind, label} ->
        MapSet.member?(ancestor_labels, label) or
          Enum.any?(matches, fn {_d, _k, l} -> l == label end)
      end)
    end
  end

  defp page_entries(pages) do
    folders =
      pages
      |> Enum.flat_map(&ancestor_folders/1)
      |> Enum.uniq()
      |> Enum.sort()

    entries =
      for folder <- folders do
        {page_depth(folder), :folder, folder}
      end ++
        for page <- pages do
          {page_depth(page), :page, page}
        end

    Enum.sort_by(entries, fn {depth, kind, label} ->
      {depth, kind_order(kind), String.downcase(label)}
    end)
  end

  defp new_page_placeholder(page) do
    if page && Path.dirname(page) != "." do
      "New in #{Path.dirname(page)}/..."
    else
      "New page..."
    end
  end

  defp new_page_default(page) do
    if page && Path.dirname(page) != "." do
      Path.dirname(page) <> "/"
    else
      ""
    end
  end

  defp kind_order(:folder), do: 0
  defp kind_order(:page), do: 1

  defp ancestor_folders(slug) do
    slug
    |> Path.split()
    |> Enum.scan([], fn part, acc -> acc ++ [part] end)
    |> Enum.map(&Enum.join(&1, "/"))
    |> Enum.slice(0..-2//1)
  end

  defp page_depth(page) do
    case Path.dirname(page) do
      "." -> 0
      dir -> dir |> Path.split() |> length()
    end
  end

  attr :entries, :list, required: true
  attr :collapsed_folders, :any, required: true
  attr :current_page, :string, required: true
  attr :draft_pages, :list, required: true
  attr :page_titles, :map, required: true
  attr :filter, :string, default: ""
  attr :parent, :string, default: nil

  def render_tree(assigns) do
    ~H"""
    <ul>
      <li
        :for={entry <- children_at(@entries, @parent, @collapsed_folders, @filter)}
        style={"padding-left: #{elem(entry, 0) * 16}px"}
      >
        <% {_depth, kind, label} = entry %>
        <%= if kind == :folder do %>
          <button
            type="button"
            phx-click="toggle_folder"
            phx-value-folder={label}
            class="flex items-center gap-1 text-xs font-semibold uppercase tracking-wide text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
          >
            <.icon
              name="hero-chevron-right-mini"
              class={
                "size-3 transition-transform" <>
                  if(not MapSet.member?(@collapsed_folders, label), do: " rotate-90", else: "")
              }
            />
            <.icon name="hero-folder-mini" class="size-4 shrink-0 text-gray-400" />
            {Path.basename(label)}
          </button>
          <.render_tree
            entries={@entries}
            collapsed_folders={@collapsed_folders}
            current_page={@current_page}
            draft_pages={@draft_pages}
            page_titles={@page_titles}
            filter={@filter}
            parent={label}
          />
        <% else %>
          <.link
            navigate={"/editor/#{label}"}
            id={"page-link-#{String.replace(label, "/", "-")}"}
            class={[
              "flex min-w-0 items-center rounded px-2 py-1 text-sm group",
              if(label == @current_page,
                do: "bg-indigo-100 dark:bg-indigo-900 text-indigo-700 dark:text-indigo-200",
                else: "text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700"
              )
            ]}
          >
            <.icon name="hero-document-text-mini" class="size-4 shrink-0 text-gray-400" />
            <span class="truncate">
              {Map.get(@page_titles, label, Path.basename(label))}
            </span>
            <span class="ml-1 hidden truncate text-xs text-gray-400 group-hover:inline" title={label}>
              {label}
            </span>
            <%= if label in @draft_pages do %>
              <span class="ml-1 text-xs font-medium uppercase text-amber-600 dark:text-amber-400">
                draft
              </span>
            <% end %>
          </.link>
        <% end %>
      </li>
    </ul>
    """
  end

  defp children_at(entries, parent, collapsed_folders, filter) do
    visible = visible_entries(entries, collapsed_folders, filter)

    Enum.filter(visible, fn {_depth, _kind, label} ->
      if parent do
        Path.dirname(label) == parent
      else
        Path.dirname(label) == "."
      end
    end)
  end

  defp load_page(socket, page, body, opts) do
    metadata = Parser.metadata(body)

    assign(socket,
      page: page,
      body: body,
      html: Parser.render_html(body),
      metadata: metadata,
      draft: Parser.draft?(metadata),
      broken_links: Content.broken_wiki_links(body, page),
      saved: Keyword.get(opts, :saved, false),
      new: Keyword.get(opts, :new, false)
    )
  end
end
