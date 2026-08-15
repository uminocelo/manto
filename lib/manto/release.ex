defmodule Manto.Release do
  @moduledoc """
  Runtime helpers used when Manto runs as a compiled release.

  Releases can't run `mix manto.init`, so `init/0` seeds the vault with a
  welcome page when it's empty. It runs automatically on application start and
  is idempotent — pages are never overwritten.
  """

  alias Manto.Content

  @doc """
  Seed the vault with `welcome.md` when it contains no pages.

  Returns `:seeded` when a welcome page was written, `:ok` otherwise.
  """
  @spec init() :: :seeded | :ok
  def init do
    if Content.list_pages() == [] do
      Content.save_page("welcome", welcome_body())
      :seeded
    else
      :ok
    end
  end

  defp welcome_body do
    """
    ---
    title: Welcome to Manto!
    author: uminocelo
    created: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    ---

    # This is Manto!

    This is your first local page.
    Edit me through the web editor at http://localhost:4000/editor
    """
  end
end
