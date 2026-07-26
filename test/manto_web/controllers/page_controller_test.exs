defmodule MantoWeb.PageControllerTest do
  use MantoWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/editor/welcome"
  end
end
