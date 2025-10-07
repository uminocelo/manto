defmodule MantoWeb.PageController do
  use MantoWeb, :controller
  alias MDEx

  def home(conn, _params) do
    render(conn, :home)
  end

  def hello(conn, _params) do
    markdown = """
      # Hello, Manto

      - Local-first
      - FOSS
      - Powered by **MDEx** 🔥
      - Emoji shortcode: :smile:
    """

    html = MDEx.new(markdown: markdown, extension: [shortcodes: true])
            |> MDEx.to_html(extension: [shortcodes: true])

    render(conn, :hello, html: html)
  end
end
