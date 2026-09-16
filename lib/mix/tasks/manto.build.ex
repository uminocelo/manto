defmodule Mix.Tasks.Manto.Build do
  use Mix.Task
  alias Manto.Content
  alias Manto.Content.Parser
  alias Manto.Fabric
  alias Manto.Fabric.PageTemplate
  alias Manto.Site

  @shortdoc "Builds all pages into a static HTML site"

  @moduledoc """
  Renders every page under priv/content into standalone static HTML.

      mix manto.build
      mix manto.build --output dist --theme dark

  Pages keep their folder structure in the output (`docs/guide.md` becomes
  `docs/guide.html`), each page gets a breadcrumb trail back to the home page,
  and every folder gets an auto-generated `index.html` listing its pages and
  subfolders. Also generates a root `index.html`, `rss.xml`, and `sitemap.xml`,
  copies content images into the output, and builds a `tag/<tag>.html`
  taxonomy page per front matter `tags:` value. Site-wide settings (title,
  description, base URL) come from a `manto.json` file in the project root.

  Options:

    * `--output`, `-o` - output directory (default: `priv/static_site`)
    * `--theme`, `-t` - theme name (built-in preset or custom theme, default: active theme from config)
  """

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
    theme_name = Keyword.get(opts, :theme) || resolve_active_theme()

    theme =
      case Fabric.get_theme(theme_name) do
        {:ok, theme} ->
          theme

        :error ->
          names = Fabric.list_themes() |> Enum.map(& &1.name)
          Mix.raise("Unknown theme #{inspect(theme_name)}. Available: #{Enum.join(names, ", ")}")
      end

    css = Fabric.render_css(theme)

    # output creation and theme copy into it
    File.mkdir_p!(output_dir)
    File.write!(Path.join(output_dir, "style.css"), css)

    # copy custom CSS file if the theme has one and it's a local file
    custom_css_href = copy_custom_css(theme, output_dir)

    site = Site.config()
    # get all pages
    pages = Content.list_pages(include_drafts: false)
    # count skipped drafts
    draft_count = Content.list_draft_pages() |> length()

    page_data =
      for name <- pages do
        body = Content.get_page(name)
        metadata = Parser.metadata(body)
        prefix = relative_prefix(name)

        html =
          Parser.render_html(body, metadata: metadata, link_prefix: prefix, link_suffix: ".html")
          |> rewrite_vault_image_paths(prefix)

        title = Map.get(metadata, "title", Path.basename(name))
        tags = metadata |> Map.get("tags", []) |> List.wrap()
        broken = Content.broken_wiki_links(body, name, include_drafts: false)

        write_output(
          output_dir,
          "#{name}.html",
          PageTemplate.render(
            site: site,
            title: title,
            body: html,
            prefix: prefix,
            current: name,
            published_at: Map.get(metadata, "published_at"),
            updated_at: Map.get(metadata, "updated_at"),
            tags: tags,
            custom_css_href: custom_css_href
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

    write_index(output_dir, site, page_data, custom_css_href)
    write_folder_indexes(output_dir, site, page_data, custom_css_href)
    write_feed(output_dir, site, page_data)
    write_sitemap(output_dir, site, page_data)
    write_tag_pages(output_dir, site, page_data, custom_css_href)
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

  # write a file into the output, creating any intermediate folders
  defp write_output(output_dir, name, content) do
    path = Path.join(output_dir, name)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end

  # "../" repeated once per folder between the page and the output root, so
  # root-relative hrefs (`prefix <> "foo.html"`) resolve from any depth
  defp relative_prefix(name) do
    depth =
      case Path.dirname(name) do
        "." -> 0
        dir -> dir |> Path.split() |> length()
      end

    String.duplicate("../", depth)
  end

  # resolve the active theme name from config, falling back to "default"
  defp resolve_active_theme do
    config = Site.config()
    fabric = Map.get(config, "fabric", %{"active" => "default"})
    Map.get(fabric, "active", "default")
  end

  # rewrite /vault-images/<path> to a relative path so static output
  # resolves correctly from any depth (dev server uses the VaultImagesPlug)
  defp rewrite_vault_image_paths(html, prefix) do
    String.replace(html, ~r/\/vault-images\/[^"'\s]+/, fn path ->
      filename = path |> String.replace_prefix("/vault-images/", "")
      prefix <> filename
    end)
  end

  # if the theme has a custom_css pointing to a local file, copy it into the
  # output directory and return the relative href for page templates
  defp copy_custom_css(theme, output_dir) do
    path = theme.custom_css

    if path != "" and File.exists?(path) do
      filename = Path.basename(path)
      File.cp!(path, Path.join(output_dir, filename))
      filename
    else
      nil
    end
  end

  # pages whose direct parent folder is `folder` ("" for the root)
  defp child_pages(page_data, folder) do
    Enum.filter(page_data, &(Path.dirname(&1.name) == if(folder == "", do: ".", else: folder)))
  end

  # direct child folders of `folder` ("" for the root), sorted
  defp child_folders(page_data, folder) do
    page_data
    |> Enum.map(&Path.dirname(&1.name))
    |> Enum.reject(&(&1 == "."))
    |> Enum.filter(&(Path.dirname(&1) == if(folder == "", do: ".", else: folder)))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp write_index(output_dir, site, page_data, custom_css_href) do
    page_items =
      child_pages(page_data, "")
      |> Enum.map(fn page ->
        date =
          if page.published_at, do: ~s(<span class="date">#{page.published_at}</span>), else: ""

        ~s(      <li><a href="#{page.name}.html">#{page.title}</a> #{date}</li>)
      end)
      |> Enum.join("\n")

    folder_items =
      child_folders(page_data, "")
      |> Enum.map(fn folder ->
        ~s(      <li><a href="#{folder}/index.html">#{Path.basename(folder)}/</a></li>)
      end)
      |> Enum.join("\n")

    items = Enum.reject([page_items, folder_items], &(&1 == "")) |> Enum.join("\n")

    custom_link =
      if custom_css_href,
        do: ~s(\n    <link rel="stylesheet" href="#{custom_css_href}" />),
        else: ""

    write_output(output_dir, "index.html", """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <title>#{site["title"]}</title>
      <link rel="stylesheet" href="style.css" />#{custom_link}
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

  # auto-generate an index.html for every folder that has pages beneath it
  defp write_folder_indexes(output_dir, site, page_data, custom_css_href) do
    page_data
    |> Enum.map(&Path.dirname(&1.name))
    |> Enum.reject(&(&1 == "."))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.each(&write_folder_index(output_dir, site, page_data, &1, custom_css_href))
  end

  defp write_folder_index(output_dir, site, page_data, folder, custom_css_href) do
    # an explicit page named `<folder>/index` wins over the auto-generated index
    if Enum.any?(page_data, &(&1.name == "#{folder}/index")) do
      :ok
    else
      prefix = relative_prefix("#{folder}/index")
      crumbs = PageTemplate.breadcrumb_html(folder, prefix)

      page_items =
        child_pages(page_data, folder)
        |> Enum.map(fn page ->
          ~s(      <li><a href="#{prefix}#{page.name}.html">#{page.title}</a></li>)
        end)
        |> Enum.join("\n")

      folder_items =
        child_folders(page_data, folder)
        |> Enum.map(fn sub ->
          ~s(      <li><a href="#{prefix}#{sub}/index.html">#{Path.basename(sub)}/</a></li>)
        end)
        |> Enum.join("\n")

      items = Enum.reject([page_items, folder_items], &(&1 == "")) |> Enum.join("\n")

      custom_link =
        if custom_css_href,
          do: ~s(\n    <link rel="stylesheet" href="#{prefix}#{custom_css_href}" />),
          else: ""

      write_output(output_dir, "#{folder}/index.html", """
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8" />
        <title>#{Path.basename(folder)} · #{site["title"]}</title>
        <link rel="stylesheet" href="#{prefix}style.css" />#{custom_link}
      </head>
      <body>
        <nav>#{crumbs}</nav>
        <article>
          <h1>#{Path.basename(folder)}</h1>
          <ul>
      #{items}
          </ul>
        </article>
      </body>
      </html>
      """)
    end
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

    write_output(output_dir, "rss.xml", """
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

    write_output(output_dir, "sitemap.xml", """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{urls}
    </urlset>
    """)
  end

  defp write_tag_pages(output_dir, site, page_data, custom_css_href) do
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

        custom_link =
          if custom_css_href,
            do: ~s(\n    <link rel="stylesheet" href="../#{custom_css_href}" />),
            else: ""

        write_output(output_dir, "tag/#{PageTemplate.tag_slug(tag)}.html", """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <title>Tag: #{tag} · #{site["title"]}</title>
          <link rel="stylesheet" href="../style.css" />#{custom_link}
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
        image <- Path.wildcard(Path.join(Content.content_dir(), "**/*.#{ext}")) do
      File.cp!(image, Path.join(output_dir, Path.basename(image)))
    end
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
