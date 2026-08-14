defmodule MantoWeb.EditorLive do
  use MantoWeb, :live_view
  alias Manto.Content
  alias Manto.Content.Parser

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       pages: Content.list_pages(),
       draft_pages: Content.list_draft_pages()
     )}
  end

  def handle_params(params, _uri, socket) do
    page = params["page"] || "welcome"
    existing_body = Content.get_page(page)
    body = existing_body || "# #{page}"
    # checks if the page exists already
    {:noreply, load_page(socket, page, body, new: is_nil(existing_body))}
  end

  def handle_event("update", %{"markdown" => body}, socket) do
    # keep the new state on each update, until a save event
    {:noreply,
     load_page(socket, socket.assigns.page, body, saved: false, new: socket.assigns.new)}
  end

  def handle_event("save", _params, socket) do
    Content.save_page(socket.assigns.page, socket.assigns.body)

    socket =
      socket
      |> assign(
        saved: true,
        new: false,
        # saves and set new to false
        pages: Content.list_pages(),
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
    case String.trim(name) |> String.replace(" ", "-") do
      "" ->
        {:noreply, socket}

      # checks if a page already exists before new page creation
      slug ->
        if slug in socket.assigns.pages do
          {:noreply, put_flash(socket, :error, "\"#{slug}\" already exists.")}
        else
          socket =
            socket
            |> put_flash(:info, "\"#{slug}\" created.")
            |> push_navigate(to: ~p"/editor/#{slug}")

          {:noreply, socket}
        end
    end
  end

  def handle_event("rename_page", %{"name" => name}, socket) do
    from = socket.assigns.page

    case String.trim(name) |> String.replace(" ", "-") do
      "" ->
        {:noreply, socket}

      to ->
        if to == from do
          {:noreply, put_flash(socket, :error, "New name is the same as the current name.")}
        else
          case Content.rename_page(from, to) do
            :ok ->
              socket =
                socket
                |> assign(pages: Content.list_pages(), draft_pages: Content.list_draft_pages())
                |> put_flash(:info, "\"#{from}\" renamed to \"#{to}\".")
                |> push_navigate(to: ~p"/editor/#{to}")

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
        socket =
          socket
          |> assign(pages: Content.list_pages(), draft_pages: Content.list_draft_pages())
          |> put_flash(:info, "\"#{page}\" deleted.")
          |> push_navigate(to: ~p"/editor")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not delete \"#{page}\".")}
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
      saved: Keyword.get(opts, :saved, false),
      new: Keyword.get(opts, :new, false)
    )
  end
end
