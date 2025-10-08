defmodule Manto.Content.Parser do
  @moduledoc """
  Wraps MDEx rendering and normalizes results into plain strings.
  """

  alias MDEx

  @doc """
  Render Markdown into safe HTML string.
  Always returns a binary, never a tuple.
  """
  def render_html(markdown) when is_binary(markdown) do
    case MDEx.to_html(markdown) do
      {:ok, html} -> html
      html when is_binary(html) -> html
      _ -> ""
    end
  end
end
