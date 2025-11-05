defmodule FireStarter.Repo do
  use Ecto.Repo,
    otp_app: :fire_starter,
    adapter: Ecto.Adapters.Postgres
end
