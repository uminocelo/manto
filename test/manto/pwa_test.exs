defmodule Manto.PwaTest do
  use MantoWeb.ConnCase

  @static_dir Path.expand("../../priv/static", __DIR__)

  test "manifest is valid JSON with expected PWA fields" do
    manifest = @static_dir |> Path.join("manifest.json") |> File.read!() |> Jason.decode!()

    assert manifest["short_name"] == "Manto"
    assert manifest["start_url"] == "/"
    assert manifest["display"] == "standalone"
    assert manifest["theme_color"] == "#1800ad"

    assert [%{"src" => "/images/icon-192.png"}, %{"src" => "/images/icon-512.png"}] =
             manifest["icons"]
  end

  test "manifest icons exist on disk" do
    manifest = @static_dir |> Path.join("manifest.json") |> File.read!() |> Jason.decode!()

    for %{"src" => src} <- manifest["icons"] do
      assert File.exists?(Path.join(@static_dir, String.trim_leading(src, "/"))),
             "missing icon at #{src}"
    end
  end

  test "service worker is emitted and handles install/fetch" do
    source = File.read!(Path.join(@static_dir, "service-worker.js"))

    assert source =~ ~s(addEventListener("install")
    assert source =~ ~s(addEventListener("fetch")
    assert source =~ "caches.match"
    assert source =~ "skipWaiting"
  end

  test "root page links the manifest and has no inline worker registration", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ ~s(<link rel="manifest" href="/manifest.json")
    refute html =~ "serviceWorker.register"
  end

  test "manifest and service worker are served", %{conn: conn} do
    conn = get(conn, ~p"/manifest.json")
    assert response(conn, 200) =~ ~s("short_name": "Manto")

    conn = get(conn, ~p"/service-worker.js")
    assert response(conn, 200) =~ "addEventListener"
  end
end
