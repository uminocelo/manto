defmodule MantoWeb.VaultImagesPlug do
  @moduledoc """
  Serves image files from the vault directory so the editor preview can
  display them. Mounted at `/vault-images` via the router.
  """

  @behaviour Plug

  import Plug.Conn

  @image_extensions ~w(.png .jpg .jpeg .gif .svg .webp .ico)

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    image_path = conn.request_path |> String.trim_leading("/")

    if image_path != "" do
      serve_image(conn, image_path)
    else
      conn
    end
  end

  defp serve_image(conn, image_path) do
    ext = Path.extname(image_path) |> String.downcase()

    if ext in @image_extensions do
      full_path = Path.join(Manto.Content.content_dir(), image_path)

      if File.regular?(full_path) and path_within_vault?(full_path) do
        conn
        |> put_resp_content_type(content_type(ext))
        |> send_file(200, full_path)
        |> halt()
      else
        conn
      end
    else
      conn
    end
  end

  defp path_within_vault?(path) do
    vault = Manto.Content.content_dir() |> Path.expand()
    expanded = path |> Path.expand()
    String.starts_with?(expanded, vault)
  end

  defp content_type(ext) do
    case ext do
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".gif" -> "image/gif"
      ".svg" -> "image/svg+xml"
      ".webp" -> "image/webp"
      ".ico" -> "image/x-icon"
      _ -> "application/octet-stream"
    end
  end
end
