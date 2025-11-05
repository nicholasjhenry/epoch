defmodule FireStarter.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :fire_starter,
    adapter: Ecto.Adapters.Postgres
end
