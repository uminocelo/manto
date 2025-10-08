defmodule MantoWeb.PlaygroundLive do
  use MantoWeb, :live_view
  alias MDEx

  @default_markdown """
  # Welcome to Manto Playground 👋

  Type some *Markdown* on the left and see it render instantly!
  """

  def mount(_params, _session, socket) do
    html = MDEx.to_html(@default_markdown)
    form = Phoenix.Component.to_form(%{"markdown" => @default_markdown}, as: :playground)

    {:ok, assign(socket, markdown: @default_markdown, html: html, form: form)}
  end

  def handle_event("update", %{"markdown" => body}, socket) do
    html = MDEx.to_html(body)
    {:noreply, assign(socket, markdown: body, html: html)}
  end
end
