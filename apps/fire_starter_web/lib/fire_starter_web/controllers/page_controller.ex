defmodule FireStarterWeb.PageController do
  use FireStarterWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
