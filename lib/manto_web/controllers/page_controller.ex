defmodule MantoWeb.PageController do
  use MantoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
