defmodule Manto.Content do
  @moduledoc """
  Handles reading and writing Markdown files from priv/content.
  """

  alias Manto.Content.Parser

  @content_dir Path.join(:code.priv_dir(:manto), "content")

  @doc """
  List all available pages (filenames without .md).

  Options:

    * `:include_drafts` - when `false`, draft pages are excluded. Defaults to `true`.
  """
  def list_pages(opts \\ []) do
    include_drafts? = Keyword.get(opts, :include_drafts, true)

    @content_dir
    |> Path.join("*.md")
    |> Path.wildcard()
    |> Enum.map(&Path.basename(&1, ".md"))
    |> Enum.reject(fn name -> not include_drafts? and draft?(name) end)
  end

  @doc "List page names whose metadata marks them as drafts."
  def list_draft_pages do
    list_pages()
    |> Enum.filter(&draft?/1)
  end

  @doc "Whether the page's front matter marks it as a draft."
  def draft?(name) do
    case get_page(name) do
      nil -> false
      body -> body |> Parser.metadata() |> Parser.draft?()
    end
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

  @doc """
  Delete a page file.

  Returns `:ok` on success, `{:error, :not_found}` when the page doesn't exist,
  or `{:error, reason}` when the file system refuses.
  """
  def delete_page(name) do
    path = Path.join(@content_dir, "#{name}.md")

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Rename a page file.

  Returns `:ok` on success, `{:error, :not_found}` when the source page doesn't
  exist, `{:error, :already_exists}` when the target already has a file, or
  `{:error, reason}` when the file system refuses.
  """
  def rename_page(from, to) do
    source = Path.join(@content_dir, "#{from}.md")
    target = Path.join(@content_dir, "#{to}.md")

    cond do
      not File.exists?(source) ->
        {:error, :not_found}

      File.exists?(target) ->
        {:error, :already_exists}

      true ->
        case File.rename(source, target) do
          :ok -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
