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
       draft_pages: Content.list_draft_pages()
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

  defp page_entries(pages) do
    folders =
      pages
      |> Enum.map(&Path.dirname/1)
      |> Enum.reject(&(&1 == "."))
      |> Enum.uniq()

    entries =
      for folder <- folders do
        {page_depth(folder), :folder, folder}
      end ++
        for page <- pages do
          {page_depth(page), :page, page}
        end

    Enum.sort_by(entries, fn {_depth, _kind, label} -> label end)
  end

  defp page_depth(page) do
    case Path.dirname(page) do
      "." -> 0
      dir -> dir |> Path.split() |> length()
    end
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
