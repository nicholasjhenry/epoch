defmodule EpochWeb.PageController do
  use EpochWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
