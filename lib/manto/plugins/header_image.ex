defmodule Manto.Plugins.HeaderImage do
  @moduledoc """
  Header Image plugin for Manto.

  Injects a styled banner `<div>` containing the page's `header_image`
  front matter value. The banner is placed before the first `<h1>` in
  the rendered HTML, or at the top of the content if no `<h1>` exists.

  If no `header_image` key is present in metadata, the HTML is returned
  unchanged.

  ## Usage

  Enable in `manto.json`:

      { "plugins": ["header_image"] }

  Then add `header_image` to the page's front matter:

      ---
      title: My Page
      header_image: /images/hero.png
      ---

      # My Page
      Content here.

  The plugin renders a `<div class="header-image-banner">` with the image
  before the `<h1>`. You can style it with a custom CSS theme or the
  default stylesheet:

      .header-image-banner img {
        width: 100%;
        height: auto;
        border-radius: 8px;
      }
  """

  @behaviour Manto.Plugin

  @impl true
  def transform_html(html, %{"header_image" => path}) when is_binary(path) and path != "" do
    src = rewrite_image_path(path)

    banner =
      ~s(<div class="header-image-banner"><img src="#{src}" alt="header image" /></div>)

    case Regex.run(~r/<h1[^>]*>/, html) do
      [tag | _] ->
        String.replace(html, tag, banner <> "\n" <> tag, global: false)

      nil ->
        banner <> "\n" <> html
    end
  end

  def transform_html(html, _metadata), do: html

  defp rewrite_image_path("http://" <> _ = url), do: url
  defp rewrite_image_path("https://" <> _ = url), do: url
  defp rewrite_image_path("/" <> _ = path), do: path
  defp rewrite_image_path(relative), do: "/vault-images/#{relative}"
end
