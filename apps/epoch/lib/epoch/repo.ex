defmodule Epoch.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :epoch,
    adapter: Ecto.Adapters.Postgres
end
