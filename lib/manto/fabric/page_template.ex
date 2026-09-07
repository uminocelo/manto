defmodule Manto.Fabric.PageTemplate do
  @moduledoc """
  Shared HTML page template for the static build output and the editor preview.

  `render/1` produces a full HTML5 document with breadcrumb nav, optional
  published/updated dates, optional tag links, and a stylesheet reference
  or inline `<style>` block.
  """

  @doc """
  Render a full HTML page.

  Accepts keyword assigns:

  - `:site` — site config map (must have `"title"` key)
  - `:title` — page title string
  - `:body` — rendered HTML body content
  - `:prefix` — relative path prefix (e.g. `"../"` for nested pages)
  - `:current` — the page slug (e.g. `"docs/guide"`)
  - `:published_at` — optional date string
  - `:updated_at` — optional date string
  - `:tags` — optional list of tag strings
  - `:stylesheet_href` — optional path to a stylesheet (defaults to `"<prefix>style.css"`)
  - `:inline_style` — optional inline CSS string (renders inside `<style>` tag, takes precedence over `stylesheet_href`)
  - `:custom_css_href` — optional path to a custom CSS file (renders as an additional `<link>` tag after the main stylesheet)
  """
  @spec render(Keyword.t()) :: String.t()
  def render(assigns) do
    crumbs = breadcrumb_html(assigns[:current], assigns[:prefix])

    meta =
      [
        assigns[:published_at] &&
          ~s(<p class="published">Published on #{assigns[:published_at]}</p>),
        assigns[:updated_at] && ~s(<p class="updated">Updated on #{assigns[:updated_at]}</p>)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    tags =
      case assigns[:tags] do
        nil ->
          nil

        [] ->
          nil

        tags ->
          ~s(<p class="tags">) <>
            Enum.map_join(tags, ", ", &tag_link(assigns[:prefix], &1)) <> "</p>"
      end

    stylesheet =
      if assigns[:inline_style] do
        ~s(<style>\n#{assigns[:inline_style]}\n</style>)
      else
        href = assigns[:stylesheet_href] || "#{assigns[:prefix]}style.css"
        ~s(<link rel="stylesheet" href="#{href}" />)
      end

    custom =
      if assigns[:custom_css_href] do
        ~s(\n    <link rel="stylesheet" href="#{assigns[:custom_css_href]}" />)
      else
        ""
      end

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <title>#{assigns[:title]} · #{assigns[:site]["title"]}</title>
      #{stylesheet}#{custom}
    </head>
    <body>
      <nav>#{crumbs}</nav>
      <article>
    #{meta}
    #{tags}
    #{assigns[:body]}
      </article>
    </body>
    </html>
    """
  end

  @doc """
  Render the preview body content (without the HTML document wrapper).

  Produces the `<style>`, `<nav>`, and `<article>` elements suitable for
  injection into a shadow DOM. Links are root-relative (`/editor/Slug`)
  so they navigate the top-level page naturally.

  Same keyword assigns as `render/1` (except `:stylesheet_href` and `:custom_css_href`
  are ignored since the preview always uses `:inline_style`).
  """
  @spec render_preview_body(Keyword.t()) :: String.t()
  def render_preview_body(assigns) do
    crumbs = breadcrumb_html(assigns[:current], assigns[:prefix])

    meta =
      [
        assigns[:published_at] &&
          ~s(<p class="published">Published on #{assigns[:published_at]}</p>),
        assigns[:updated_at] && ~s(<p class="updated">Updated on #{assigns[:updated_at]}</p>)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    tags =
      case assigns[:tags] do
        nil -> nil
        [] -> nil
        tags ->
          ~s(<p class="tags">) <>
            Enum.map_join(tags, ", ", &tag_link(assigns[:prefix], &1)) <> "</p>"
      end

    stylesheet =
      if assigns[:inline_style] do
        ~s(<style>\n#{assigns[:inline_style]}\n</style>)
      else
        ""
      end

    custom_css =
      if assigns[:custom_css_href] do
        ~s(<link rel="stylesheet" href="#{assigns[:custom_css_href]}" />)
      else
        ""
      end

    """
    #{stylesheet}
    #{custom_css}
    <nav>#{crumbs}</nav>
    <article>
    #{meta}
    #{tags}
    #{assigns[:body]}
    </article>
    """
  end

  @doc """
  Generate breadcrumb trail HTML: `Home / folder / ... / current_label`.
  """
  @spec breadcrumb_html(String.t(), String.t()) :: String.t()
  def breadcrumb_html(context, prefix) do
    current_label = Path.basename(context)

    dirs =
      case Path.dirname(context) do
        "." -> []
        dir -> Path.split(dir)
      end

    ancestor_links =
      for {dir, i} <- Enum.with_index(dirs, 1) do
        folder = Enum.take(dirs, i) |> Enum.join("/")
        ~s(<a href="#{prefix}#{folder}/index.html">#{dir}</a>)
      end

    ([~s(<a href="#{prefix}index.html">Home</a>)] ++ ancestor_links ++ [current_label])
    |> Enum.join(" / ")
  end

  @doc """
  Generate a tag link HTML.
  """
  @spec tag_link(String.t(), String.t()) :: String.t()
  def tag_link(prefix, tag) do
    ~s(<a href="#{prefix}tag/#{tag_slug(tag)}.html">#{tag}</a>)
  end

  @doc """
  Normalize a tag string to a URL-safe slug.
  """
  @spec tag_slug(String.t()) :: String.t()
  def tag_slug(tag) do
    tag
    |> String.trim()
    |> String.replace(" ", "-")
    |> String.downcase()
  end
end
