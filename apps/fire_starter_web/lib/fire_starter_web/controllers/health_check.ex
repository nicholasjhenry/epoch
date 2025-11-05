defmodule FireStarterWeb.HealthCheck do
  @moduledoc false
  use FireStarterWeb, :controller

  def health(conn, _) do
    send_resp(conn, 200, "ok")
  end
end
