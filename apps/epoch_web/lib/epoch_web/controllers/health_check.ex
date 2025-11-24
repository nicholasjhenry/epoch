defmodule EpochWeb.HealthCheck do
  @moduledoc false
  use EpochWeb, :controller

  def health(conn, _) do
    send_resp(conn, 200, "ok")
  end
end
