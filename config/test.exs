import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :epoch, Epoch.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "epoch_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: String.to_integer(System.get_env("DATABASE_PORT", "5432")),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :epoch_web, EpochWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "OpsxEx0BeXV/wdV1QHo7uNDnuidf+yc4L7OYtmzHEK9pcukDzEwCHlxG7TuljwcY",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# In test we don't send emails
config :epoch, Epoch.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
