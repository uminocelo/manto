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
    Mix.Task.run("app.start") # start app before running the task, depends on Manto.Content module

    {opts, _} = # parses arguments from command
      OptionParser.parse!(args,
        strict: [output: :string, theme: :string],
        aliases: [o: :output, t: :theme]
      )

    output_dir = Keyword.get(opts, :output, "priv/static_site")
    theme = Keyword.get(opts, :theme, "default")
    theme_path = Path.join([:code.priv_dir(:manto), "themes", "#{theme}.css"])

    unless File.exists?(theme_path) do # validates if theme exists
      Mix.raise("Unknown theme #{inspect(theme)} (looked for #{theme_path})")
    end

    File.mkdir_p!(output_dir) # output creation and theme copy into it
    File.cp!(theme_path, Path.join(output_dir, "style.css"))

    pages = Content.list_pages() # get all pages

    for name <- pages do # get content and creates html file
      body = Content.get_page(name)
      metadata = Parser.metadata(body)
      html = Parser.render_html(body, link_prefix: "", link_suffix: ".html")
      title = Map.get(metadata, "title", name)

      File.write!(
        Path.join(output_dir, "#{name}.html"),
        page_template(title: title, body: html, pages: pages, current: name)
      )
    end

    Mix.shell().info("Built #{length(pages)} page(s) into #{output_dir}/") # prints success message
  end

  defp page_template(assigns) do # template for each page
    nav =
      Enum.map_join(assigns[:pages], "\n", fn name ->
        ~s(<a href="#{name}.html">#{name}</a>)
      end)

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
    #{assigns[:body]}
      </article>
    </body>
    </html>
    """
  end
end
