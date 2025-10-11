defmodule Mix.Tasks.Manto.Init do
  use Mix.Task

  @shortdoc "Initializes Manto: creates content folder and seeds example pages"

  @moduledoc """
  A Mix task to initialize Manto configuration.

  This task creates a default configuration file for Manto if it does not already exist.
  """

  @impl true
  def run(_args) do
    Mix.shell().info("Initializing Manto...")
    content_dir = Path.join([File.cwd!(), "priv", "content"])
    File.mkdir_p!(content_dir)

    welcome_path = Path.join(content_dir, "welcome.md")
    unless File.exists?(welcome_path) do
      Mix.shell().info("Seeding welcome.md...")
      File.write!(welcome_path, """
      # Welcome to Manto!

      This is your first local page.
      Edit me in `priv/content/welcome.md` or through the web editor!
      """)
    else
      Mix.shell().info("welcome.md already exists, skipping seeding.")
    end

    Mix.shell().info("Manto initialized successfully!")
  end
end
