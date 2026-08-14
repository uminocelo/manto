defmodule Mix.Tasks.Manto.Build do
  use Mix.Task
  alias Manto.Content
  alias Manto.Content.Parser
  alias Manto.Site

  @shortdoc "Builds all pages into a static HTML site"

  @moduledoc """
  Renders every page under priv/content into standalone static HTML.

      mix manto.build
      mix manto.build --output dist --theme dark

  Generates `index.html`, `rss.xml`, and `sitemap.xml`, copies content images
  into the output, and builds a `tag/<tag>.html` taxonomy page per front matter
  `tags:` value. Site-wide settings (title, description, base URL) come from a
  `manto.json` file in the project root.

  Options:

    * `--output`, `-o` - output directory (default: `priv/static_site`)
    * `--theme`, `-t` - theme name from `priv/themes/*.css` (default: `default`)
  """

  @content_dir Path.join(:code.priv_dir(:manto), "content")
  @image_extensions ~w(png jpg jpeg gif svg webp)

  @impl true
  def run(args) do
    # start app before running the task, depends on Manto.Content module
    Mix.Task.run("app.start")

    # parses arguments from command
    {opts, _} =
      OptionParser.parse!(args,
        strict: [output: :string, theme: :string],
        aliases: [o: :output, t: :theme]
      )

    output_dir = Keyword.get(opts, :output, "priv/static_site")
    theme = Keyword.get(opts, :theme, "default")
    theme_path = Path.join([:code.priv_dir(:manto), "themes", "#{theme}.css"])

    # validates if theme exists
    unless File.exists?(theme_path) do
      Mix.raise("Unknown theme #{inspect(theme)} (looked for #{theme_path})")
    end

    # output creation and theme copy into it
    File.mkdir_p!(output_dir)
    File.cp!(theme_path, Path.join(output_dir, "style.css"))

    site = Site.config()
    # get all pages
    pages = Content.list_pages(include_drafts: false)
    # count skipped drafts
    draft_count = Content.list_draft_pages() |> length()

    page_data =
      for name <- pages do
        body = Content.get_page(name)
        metadata = Parser.metadata(body)
        html = Parser.render_html(body, link_prefix: "", link_suffix: ".html")
        title = Map.get(metadata, "title", name)
        tags = metadata |> Map.get("tags", []) |> List.wrap()
        broken = Content.broken_wiki_links(body, name, include_drafts: false)

        File.write!(
          Path.join(output_dir, "#{name}.html"),
          page_template(
            site: site,
            title: title,
            body: html,
            pages: pages,
            current: name,
            published_at: Map.get(metadata, "published_at"),
            updated_at: Map.get(metadata, "updated_at"),
            tags: tags
          )
        )

        %{
          name: name,
          title: title,
          published_at: Map.get(metadata, "published_at"),
          updated_at: Map.get(metadata, "updated_at"),
          tags: tags,
          broken: broken
        }
      end

    write_index(output_dir, site, page_data)
    write_feed(output_dir, site, page_data)
    write_sitemap(output_dir, site, page_data)
    write_tag_pages(output_dir, site, page_data)
    copy_images(output_dir)

    broken_links =
      page_data
      |> Enum.map(&{&1.name, &1.broken})
      |> Enum.reject(fn {_name, broken} -> broken == [] end)

    skipped = if draft_count == 0, do: "", else: " (skipped #{draft_count} draft(s))"

    # prints success message
    Mix.shell().info("Built #{length(pages)} page(s) into #{output_dir}/#{skipped}")

    if broken_links != [] do
      Mix.shell().info("\nBroken links:")

      for {name, broken} <- broken_links do
        links = Enum.map_join(broken, ", ", &"[[#{&1}]]")
        Mix.shell().info("  * #{name}.html -> #{links}")
      end
    end
  end

  # template for each page
  defp page_template(assigns) do
    nav =
      Enum.map_join(assigns[:pages], "\n", fn name ->
        ~s(<a href="#{name}.html">#{name}</a>)
      end)

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
        [] -> nil
        tags -> ~s(<p class="tags">) <> Enum.map_join(tags, ", ", &tag_link/1) <> "</p>"
      end

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <title>#{assigns[:title]} · #{assigns[:site]["title"]}</title>
      <link rel="stylesheet" href="style.css" />
    </head>
    <body>
      <nav><a href="index.html">Home</a> — #{nav}</nav>
      <article>
    #{meta}
    #{tags}
    #{assigns[:body]}
      </article>
    </body>
    </html>
    """
  end

  defp write_index(output_dir, site, page_data) do
    items =
      Enum.map_join(page_data, "\n", fn page ->
        date =
          if page.published_at, do: ~s(<span class="date">#{page.published_at}</span>), else: ""

        ~s(      <li><a href="#{page.name}.html">#{page.title}</a> #{date}</li>)
      end)

    File.write!(Path.join(output_dir, "index.html"), """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <title>#{site["title"]}</title>
      <link rel="stylesheet" href="style.css" />
    </head>
    <body>
      <nav><a href="index.html">Home</a></nav>
      <article>
        <h1>#{site["title"]}</h1>
        <p>#{site["description"]}</p>
        <ul>
    #{items}
        </ul>
      </article>
    </body>
    </html>
    """)
  end

  defp write_feed(output_dir, site, page_data) do
    base = String.trim_trailing(site["base_url"], "/")

    items =
      Enum.map_join(page_data, "\n", fn page ->
        """
        <item>
          <title>#{xml_escape(page.title)}</title>
          <link>#{base}/#{page.name}.html</link>
          <guid>#{base}/#{page.name}.html</guid>
          #{if pub_date = rss_pubdate(page.published_at), do: "<pubDate>#{pub_date}</pubDate>"}
          <description>#{xml_escape(page.title)}</description>
        </item>
        """
      end)

    File.write!(Path.join(output_dir, "rss.xml"), """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>#{xml_escape(site["title"])}</title>
        <description>#{xml_escape(site["description"])}</description>
        <link>#{base}/</link>
    #{items}
      </channel>
    </rss>
    """)
  end

  defp write_sitemap(output_dir, site, page_data) do
    base = String.trim_trailing(site["base_url"], "/")

    urls =
      Enum.map_join(page_data, "\n", fn page ->
        lastmod = if page.updated_at, do: "<lastmod>#{page.updated_at}</lastmod>", else: ""

        ~s(  <url><loc>#{base}/#{page.name}.html</loc>#{lastmod}</url>)
      end)

    File.write!(Path.join(output_dir, "sitemap.xml"), """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{urls}
    </urlset>
    """)
  end

  defp write_tag_pages(output_dir, site, page_data) do
    tags =
      Enum.reduce(page_data, %{}, fn page, acc ->
        Enum.reduce(page.tags, acc, fn tag, acc ->
          Map.update(acc, tag, [page], &[page | &1])
        end)
      end)

    if map_size(tags) > 0 do
      File.mkdir_p!(Path.join(output_dir, "tag"))

      for {tag, tag_pages} <- tags do
        items =
          Enum.map_join(tag_pages, "\n", fn page ->
            ~s(      <li><a href="../#{page.name}.html">#{page.title}</a></li>)
          end)

        File.write!(Path.join([output_dir, "tag", "#{tag_slug(tag)}.html"]), """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <title>Tag: #{tag} · #{site["title"]}</title>
          <link rel="stylesheet" href="../style.css" />
        </head>
        <body>
          <nav><a href="../index.html">Home</a></nav>
          <article>
            <h1>Tag: #{tag}</h1>
            <ul>
        #{items}
            </ul>
          </article>
        </body>
        </html>
        """)
      end
    end
  end

  defp copy_images(output_dir) do
    for ext <- @image_extensions,
        image <- Path.wildcard(Path.join(@content_dir, "**/*.#{ext}")) do
      File.cp!(image, Path.join(output_dir, Path.basename(image)))
    end
  end

  defp tag_link(tag) do
    ~s(<a href="tag/#{tag_slug(tag)}.html">#{tag}</a>)
  end

  defp tag_slug(tag) do
    tag
    |> String.trim()
    |> String.replace(" ", "-")
    |> String.downcase()
  end

  defp rss_pubdate(%Date{} = date) do
    date
    |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    |> Calendar.strftime("%a, %d %b %Y %H:%M:%S %z")
  end

  defp rss_pubdate(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S %z")
  end

  defp rss_pubdate(_), do: nil

  defp xml_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
