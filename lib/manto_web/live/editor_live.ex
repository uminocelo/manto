defmodule MantoWeb.EditorLive do
  use MantoWeb, :live_view
  alias Manto.Content
  alias Manto.Content.Parser

  def mount(_params, _session, socket) do
    page = "welcome"
    body = Content.get_page(page) || "# New Page"
    html = Parser.render_html(body)

    {:ok, assign(socket, page: page, body: body, html: html, saved: false)}
  end

  def handle_event("update", %{"markdown" => body}, socket) do
    html = Parser.render_html(body)
    {:noreply, assign(socket, body: body, html: html, saved: false)}
  end

  def handle_event("save", _params, socket) do
    Content.save_page(socket.assigns.page, socket.assigns.body)
    {:noreply, assign(socket, saved: true)}
  end
end
