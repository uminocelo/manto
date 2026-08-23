defmodule Manto.Content do
  @moduledoc """
  Handles reading and writing Markdown files in the configured vault.
  """

  alias Manto.Content.Parser
  alias Manto.Site

  @doc """
  Absolute path of the vault directory.

  Taken from the `vault_path` site config, which may be absolute, start with
  `~`, or be relative to the project root. Defaults to `priv/content`.
  """
  @spec content_dir() :: String.t()
  def content_dir do
    Path.expand(Site.config()["vault_path"])
  end

  @doc """
  List all available pages (paths relative to the vault, without `.md`).

  Pages in subfolders keep their folder, e.g. `"docs/guides/setup"`.

  Options:

    * `:include_drafts` - when `false`, draft pages are excluded. Defaults to `true`.
  """
  def list_pages(opts \\ []) do
    include_drafts? = Keyword.get(opts, :include_drafts, true)

    content_dir()
    |> Path.join("**/*.md")
    |> Path.wildcard()
    |> Enum.map(fn path ->
      path |> Path.relative_to(content_dir()) |> Path.rootname()
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reject(fn name -> not include_drafts? and draft?(name) end)
  end

  @doc "List page names whose metadata marks them as drafts."
  def list_draft_pages do
    list_pages()
    |> Enum.filter(&draft?/1)
  end

  @doc """
  Return a map of page slug → title from front matter, falling back to the slug when no title is set.

  Reads each page once to extract the `title` field from YAML front matter.
  """
  @spec list_titles() :: %{String.t() => String.t()}
  def list_titles do
    list_pages()
    |> Enum.map(fn slug ->
      title =
        case get_page(slug) do
          nil -> slug
          body -> body |> Parser.metadata() |> Map.get("title", slug)
        end

      {slug, title}
    end)
    |> Map.new()
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
    path = Path.join(content_dir(), "#{name}.md")

    case File.read(path) do
      {:ok, body} -> body
      {:error, _} -> nil
    end
  end

  @doc """
  Return the slugified `[[wiki link]]` targets in `markdown` that don't match
  any existing page.

  Options:

    * `:include_drafts` - when `false`, links to draft pages count as broken
      (their pages won't be published). Defaults to `true`.
  """
  @spec broken_wiki_links(String.t(), String.t() | nil, keyword()) :: [String.t()]
  def broken_wiki_links(markdown, current_page \\ nil, opts \\ []) do
    existing = list_pages(opts)

    markdown
    |> Parser.wiki_link_targets()
    |> Enum.reject(&(&1 == current_page))
    |> Enum.reject(&(&1 in existing))
  end

  @doc "Save Markdown body to a page (creates or overwrites)"
  def save_page(name, body) do
    path = Path.join(content_dir(), "#{name}.md")
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, body)
  end

  @doc """
  Delete a page file.

  Returns `:ok` on success, `{:error, :not_found}` when the page doesn't exist,
  or `{:error, reason}` when the file system refuses.
  """
  def delete_page(name) do
    path = Path.join(content_dir(), "#{name}.md")

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
    source = Path.join(content_dir(), "#{from}.md")
    target = Path.join(content_dir(), "#{to}.md")

    cond do
      not File.exists?(source) ->
        {:error, :not_found}

      File.exists?(target) ->
        {:error, :already_exists}

      true ->
        File.mkdir_p!(Path.dirname(target))

        case File.rename(source, target) do
          :ok -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Whether `name` is a safe page slug.

  Rejects empty names, absolute paths, and segments that are `""`, `"."`, or
  `".."`, so nested names like `"docs/guides/setup"` are allowed but nothing
  can escape the vault.
  """
  @spec valid_page_name?(String.t()) :: boolean()
  def valid_page_name?(name) do
    name = String.trim(name)

    name != "" and
      not String.starts_with?(name, "/") and
      name
      |> String.split("/")
      |> Enum.all?(fn segment -> segment not in ["", ".", ".."] end)
  end
end
