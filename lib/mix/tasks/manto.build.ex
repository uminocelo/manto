defmodule Mix.Tasks.Manto.Build do
  use Mix.Task
  alias Manto.Content
  alias Manto.Content.Parser

  @shortdoc "Builds all pages into a static HTML site"

  @moduledoc """
  Renders every page under priv/content into standalone static HTML.

      mix manto.build
      mix manto.build --output dist --theme dark

  Options:

    * `--output`, `-o` - output directory (default: `priv/static_site`)
    * `--theme`, `-t` - theme name from `priv/themes/*.css` (default: `default`)
  """

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

    # get all pages
    pages = Content.list_pages(include_drafts: false)
    # count skipped drafts
    draft_count = Content.list_draft_pages() |> length()

    # get content and creates html file
    broken_links =
      for name <- pages do
        body = Content.get_page(name)
        metadata = Parser.metadata(body)
        html = Parser.render_html(body, link_prefix: "", link_suffix: ".html")
        title = Map.get(metadata, "title", name)

        broken = Content.broken_wiki_links(body, name, include_drafts: false)

        File.write!(
          Path.join(output_dir, "#{name}.html"),
          page_template(
            title: title,
            body: html,
            pages: pages,
            current: name,
            published_at: Map.get(metadata, "published_at"),
            updated_at: Map.get(metadata, "updated_at")
          )
        )

        if broken == [], do: nil, else: {name, broken}
      end
      |> Enum.reject(&is_nil/1)

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

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <title>#{assigns[:title]}</title>
      <link rel="stylesheet" href="style.css" />
    </head>
    <body>
      <nav>#{nav}</nav>
      <article>
    #{meta}
    #{assigns[:body]}
      </article>
    </body>
    </html>
    """
  end
end
