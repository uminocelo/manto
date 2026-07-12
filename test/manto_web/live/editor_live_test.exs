defmodule MantoWeb.EditorLiveTest do
  use MantoWeb.ConnCase
  import Phoenix.LiveViewTest

  test "new page button navigates to a fresh page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/editor")

    {:error, {:live_redirect, %{to: to}}} =
      view
      |> form("form[phx-submit=new_page]", %{name: "My Draft"})
      |> render_submit()

    assert to == "/editor/My-Draft"

    {:ok, view2, html} = live(conn, to)
    assert html =~ "My-Draft"
    assert html =~ "created"
    assert render(view2) =~ "# My-Draft"
  end

  test "flags an unsaved page as new and clears the flag once saved", %{conn: conn} do
    page = "Brand-New-Page-#{System.unique_integer([:positive])}"
    path = Path.join([:code.priv_dir(:manto), "content", "#{page}.md"])
    on_exit(fn -> File.rm(path) end)

    {:ok, view, html} = live(conn, "/editor/#{page}")
    assert html =~ "Draft created!"

    html =
      view
      |> form("form[phx-submit=save]", %{markdown: "# #{page}"})
      |> render_submit()

    refute html =~ "Draft created!"
  end

  test "does not flag an existing page as new", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/editor/welcome")
    refute html =~ "Draft created!"
  end

  test "warns via flash instead of navigating when the page name already exists", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/editor")

    html =
      view
      |> form("form[phx-submit=new_page]", %{name: "welcome"})
      |> render_submit()

    # a plain string (not a live_redirect tuple) proves no navigation happened
    assert html =~ "already exists"
  end
end
