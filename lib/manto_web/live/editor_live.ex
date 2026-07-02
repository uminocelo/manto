defmodule MantoWeb.EditorLive do
  use MantoWeb, :live_view
  alias Manto.Content
  alias Manto.Content.Parser

  def mount(_params, _session, socket) do
    {:ok, assign(socket, pages: Content.list_pages())}
  end

  def handle_params(params, _uri, socket) do
    page = params["page"] || "welcome"
    existing_body = Content.get_page(page)
    body = existing_body || "# #{page}"
    {:noreply, load_page(socket, page, body, new: is_nil(existing_body))} # checks if the page exists already
  end

  def handle_event("update", %{"markdown" => body}, socket) do
    {:noreply, load_page(socket, socket.assigns.page, body, saved: false, new: socket.assigns.new)} # keep the new state on each update, until a save event
  end

  def handle_event("save", _params, socket) do
    Content.save_page(socket.assigns.page, socket.assigns.body)

    socket =
      socket
      |> assign(saved: true, new: false, pages: Content.list_pages()) # saves and set new to false
      |> put_flash(:info, "\"#{socket.assigns.page}\" saved.")

    {:noreply, socket}
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

  defp load_page(socket, page, body, opts) do
    assign(socket,
      page: page,
      body: body,
      html: Parser.render_html(body),
      metadata: Parser.metadata(body),
      saved: Keyword.get(opts, :saved, false),
      new: Keyword.get(opts, :new, false)
    )
  end
end
