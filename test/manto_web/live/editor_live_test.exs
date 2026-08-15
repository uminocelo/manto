defmodule MantoWeb.EditorLiveTest do
  use MantoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  test "new page button navigates to a fresh page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/editor")

    result =
      view
      |> form("form[phx-submit=new_page]", %{name: "My Draft"})
      |> render_submit()

    {:error, {:live_redirect, %{to: to}}} = result
    assert to == "/editor/My-Draft"

    # follow the redirect so the "created" flash survives, like a real browser
    {:ok, view2, html} = follow_redirect(result, conn)
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

  test "restores an autosaved draft via the restore_draft event", %{conn: conn} do
    page = "Restore-Ed-#{System.unique_integer([:positive])}"
    path = Path.join([:code.priv_dir(:manto), "content", "#{page}.md"])
    on_exit(fn -> File.rm(path) end)

    {:ok, view, _html} = live(conn, "/editor/#{page}")

    html = render_hook(view, "restore_draft", %{"body" => "# Restored Draft"})

    assert html =~ "# Restored Draft"
    refute html =~ "# #{page}"
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

  test "shows a draft badge and dates for a draft page", %{conn: conn} do
    page = "Draft-Show-#{System.unique_integer([:positive])}"
    path = Path.join([:code.priv_dir(:manto), "content", "#{page}.md"])

    File.write!(path, """
    ---
    draft: true
    published_at: 2026-08-13
    ---

    # #{page}
    """)

    on_exit(fn -> File.rm(path) end)

    {:ok, view, html} = live(conn, "/editor/#{page}")

    assert has_element?(view, "#draft-badge")
    assert html =~ "Published 2026-08-13"
    assert html =~ "draft"
  end

  test "does not show a draft badge for a published page", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/editor/welcome")
    refute has_element?(view, "#draft-badge")
  end

  test "renames the current page and navigates to the new name", %{conn: conn} do
    page = "Rename-Ed-#{System.unique_integer([:positive])}"
    path = Path.join([:code.priv_dir(:manto), "content", "#{page}.md"])
    File.write!(path, "# #{page}")
    on_exit(fn -> File.rm(path) end)

    new_name = "Renamed-Ed-#{System.unique_integer([:positive])}"
    new_path = Path.join([:code.priv_dir(:manto), "content", "#{new_name}.md"])
    on_exit(fn -> File.rm(new_path) end)

    {:ok, view, _html} = live(conn, "/editor/#{page}")

    {:error, {:live_redirect, %{to: to}}} =
      view
      |> form("form[phx-submit=rename_page]", %{name: new_name})
      |> render_submit()

    assert to == "/editor/#{new_name}"
    refute File.exists?(path)
    assert File.exists?(new_path)
  end

  test "warns via flash when renaming to an existing page", %{conn: conn} do
    page = "Rename-Occupied-#{System.unique_integer([:positive])}"
    path = Path.join([:code.priv_dir(:manto), "content", "#{page}.md"])
    File.write!(path, "# #{page}")
    on_exit(fn -> File.rm(path) end)

    {:ok, view, _html} = live(conn, "/editor/#{page}")

    html =
      view
      |> form("form[phx-submit=rename_page]", %{name: "welcome"})
      |> render_submit()

    assert html =~ "already exists"
    assert File.exists?(path)
  end

  test "deletes the current page and navigates to the editor root", %{conn: conn} do
    page = "Delete-Ed-#{System.unique_integer([:positive])}"
    path = Path.join([:code.priv_dir(:manto), "content", "#{page}.md"])
    File.write!(path, "# #{page}")
    on_exit(fn -> File.rm(path) end)

    {:ok, view, _html} = live(conn, "/editor/#{page}")

    {:error, {:live_redirect, %{to: to}}} =
      view
      |> element("button[phx-click=delete_page]")
      |> render_click()

    assert to == "/editor"
    refute File.exists?(path)
  end

  test "lists broken wiki links in the sidebar and updates them while typing", %{conn: conn} do
    page = "Broken-Ed-#{System.unique_integer([:positive])}"
    path = Path.join([:code.priv_dir(:manto), "content", "#{page}.md"])
    File.write!(path, "See [[Missing-One-ABC]].")
    on_exit(fn -> File.rm(path) end)

    {:ok, view, _html} = live(conn, "/editor/#{page}")

    assert has_element?(view, "#broken-links")
    assert has_element?(view, "#broken-links li", "Missing-One-ABC")

    html =
      view
      |> form("form[phx-submit=save]", %{markdown: "Fixed, no links left."})
      |> render_change()

    refute html =~ "broken-links"
    assert html =~ "Fixed, no links left."
  end

  test "hides the broken-links section when there are none", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/editor/welcome")
    refute has_element?(view, "#broken-links")
  end
end
