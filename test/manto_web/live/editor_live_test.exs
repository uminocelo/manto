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

  test "lists broken wiki links in the editor column and updates them while typing", %{conn: conn} do
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

  test "new page with a folder name navigates to a fresh nested page", %{conn: conn} do
    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", "docs"])) end)

    {:ok, view, _html} = live(conn, "/editor")

    result =
      view
      |> form("form[phx-submit=new_page]", %{name: "docs/Nested Draft"})
      |> render_submit()

    {:error, {:live_redirect, %{to: to}}} = result
    assert to == "/editor/docs/Nested-Draft"

    {:ok, view2, html} = follow_redirect(result, conn)
    assert html =~ "Nested-Draft"
    assert html =~ "created"
    assert render(view2) =~ "# Nested-Draft"
  end

  test "navigates directly to a nested page", %{conn: conn} do
    folder = "direct-#{System.unique_integer([:positive])}"
    page = "#{folder}/Deep-Page"
    Manto.Content.save_page(page, "# Deep Direct")
    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    {:ok, view, html} = live(conn, "/editor/#{page}")

    assert html =~ "Deep Direct"
    assert html =~ "#{page}.md"
    assert has_element?(view, "nav ul li a", "Deep-Page")
  end

  test "lists nested pages under their folder in the sidebar", %{conn: conn} do
    folder = "side-#{System.unique_integer([:positive])}"
    page = "#{folder}/Deep-Page"
    Manto.Content.save_page(page, "# Deep Page")
    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    {:ok, view, html} = live(conn, "/editor/welcome")

    assert has_element?(view, "nav ul li a", "Deep-Page")
    assert html =~ "Deep-Page"
  end

  test "rejects an invalid page name with a flash", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/editor")

    html =
      view
      |> form("form[phx-submit=new_page]", %{name: "../evil"})
      |> render_submit()

    assert html =~ "not a valid page name"
  end

  test "renames the current page into a folder", %{conn: conn} do
    page = "Rename-Into-Folder-#{System.unique_integer([:positive])}"
    path = Path.join([:code.priv_dir(:manto), "content", "#{page}.md"])
    File.write!(path, "# #{page}")
    on_exit(fn -> File.rm(path) end)

    folder = "renamed-#{System.unique_integer([:positive])}"
    new_name = "#{folder}/Moved"
    new_path = Path.join([:code.priv_dir(:manto), "content", "#{new_name}.md"])
    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    {:ok, view, _html} = live(conn, "/editor/#{page}")

    {:error, {:live_redirect, %{to: to}}} =
      view
      |> form("form[phx-submit=rename_page]", %{name: new_name})
      |> render_submit()

    assert to == "/editor/#{new_name}"
    refute File.exists?(path)
    assert File.exists?(new_path)
  end

  test "falls back to the welcome page for an unsafe page path", %{conn: conn} do
    {:ok, view, html} = live(conn, "/editor/../evil")

    assert html =~ "welcome"
    assert render(view) =~ "welcome"
  end

  test "warns via flash when creating a nested page that already exists", %{conn: conn} do
    folder = "occupied-#{System.unique_integer([:positive])}"
    Manto.Content.save_page("#{folder}/Existing", "# Existing")
    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    {:ok, view, _html} = live(conn, "/editor")

    html =
      view
      |> form("form[phx-submit=new_page]", %{name: "#{folder}/Existing"})
      |> render_submit()

    assert html =~ "already exists"
  end

  test "sidebar shows ancestor folders for deeply nested pages", %{conn: conn} do
    folder = "deep-#{System.unique_integer([:positive])}"
    Manto.Content.save_page("#{folder}/guides/setup", "# Setup")
    Manto.Content.save_page("#{folder}/guides/usage", "# Usage")
    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    {:ok, view, _html} = live(conn, "/editor/#{folder}/guides/setup")

    # ancestor folders appear as clickable folder rows (displayed by basename)
    assert has_element?(view, "button[phx-click=toggle_folder]", folder)
    assert has_element?(view, "button[phx-click=toggle_folder]", "guides")
    assert has_element?(view, "button[phx-value-folder='#{folder}/guides']", "guides")

    # leaf pages are listed under their immediate parent
    assert has_element?(view, "nav ul li a", "setup")
    assert has_element?(view, "nav ul li a", "usage")
  end

  test "sidebar ancestors are sorted folders-first", %{conn: conn} do
    folder = "sort-#{System.unique_integer([:positive])}"
    Manto.Content.save_page("#{folder}/alpha", "# Alpha")
    Manto.Content.save_page("#{folder}/beta", "# Beta")
    # a page at the root level, not inside the folder
    zeta = "sort-zeta-#{System.unique_integer([:positive])}"
    Manto.Content.save_page(zeta, "# Zeta")

    on_exit(fn ->
      File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder]))
      File.rm(Path.join([:code.priv_dir(:manto), "content", "#{zeta}.md"]))
    end)

    {:ok, view, _html} = live(conn, "/editor")

    # folder row appears before the page row
    assert has_element?(view, "button[phx-click=toggle_folder]", folder)
    assert has_element?(view, "nav ul li a", zeta)
  end

  # --- Issue 2.1: Filter and reveal ---

  test "filter input is present in the sidebar", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/editor")
    assert has_element?(view, "#filter-form")
  end

  test "filter text narrows the visible page list", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/editor")

    # initially the welcome page is visible
    assert has_element?(view, "nav ul li a", "welcome")

    # apply a filter that doesn't match "welcome"
    view
    |> form("#filter-form", %{filter: "mobile"})
    |> render_change()

    # welcome should no longer be visible
    refute has_element?(view, "nav ul li a", "welcome")

    # clear the filter
    view
    |> form("#filter-form", %{filter: ""})
    |> render_change()

    # welcome should be back
    assert has_element?(view, "nav ul li a", "welcome")
  end

  # --- Issue 2.2: New page in context ---

  test "new page input shows folder prefix when editing a nested page", %{conn: conn} do
    folder = "newctx-#{System.unique_integer([:positive])}"
    page = "#{folder}/Existing"
    Manto.Content.save_page(page, "# Existing")
    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    {:ok, view, _html} = live(conn, "/editor/#{page}")

    # the new page input shows the folder prefix
    assert has_element?(view, "input[name=name][value='#{folder}/']")
  end

  test "new page from a nested editor creates in the current folder", %{conn: conn} do
    folder = "createin-#{System.unique_integer([:positive])}"
    page = "#{folder}/Existing"
    Manto.Content.save_page(page, "# Existing")
    on_exit(fn -> File.rm_rf(Path.join([:code.priv_dir(:manto), "content", folder])) end)

    {:ok, view, _html} = live(conn, "/editor/#{page}")

    result =
      view
      |> form("form[phx-submit=new_page]", %{name: "#{folder}/Child"})
      |> render_submit()

    {:error, {:live_redirect, %{to: to}}} = result
    assert to == "/editor/#{folder}/Child"
  end

  test "new page from root editor stays unprefixed", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/editor/welcome")

    # root page — no folder prefix in placeholder
    refute html =~ "New in"
  end
end
