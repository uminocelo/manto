defmodule Manto.Content do
  @moduledoc """
  Handles reading and writing Markdown files from priv/content.
  """

  @content_dir Path.join(:code.priv_dir(:manto), "content")

  @doc "List all available pages (filenames without .md)"
  def list_pages do
    Path.wildcard(Path.join(@content_dir, "*.md"))
    |> Enum.map(&Path.basename(&1, ".md"))
  end

  @doc "Get the raw Markdown body of a page"
  def get_page(name) do
    path = Path.join(@content_dir, "#{name}.md")

    case File.read(path) do
      {:ok, body} -> body
      {:error, _} -> nil
    end
  end

  @doc "Save Markdown body to a page (creates or overwrites)"
  def save_page(name, body) do
    path = Path.join(@content_dir, "#{name}.md")
    File.write!(path, body)
  end
end
