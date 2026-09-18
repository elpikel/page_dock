import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :page_dock, PageDock.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "page_dock_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :page_dock, PageDockWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "bG33+2bdNCP2DQJPGsgizhUabYQ8cuygFl9zFg7+60ERGazofB6caAen7/uC1iUB",
  server: false

# In test we don't send emails
config :page_dock, PageDock.Mailer, adapter: Swoosh.Adapters.Test

# GitHub OAuth: use dummy credentials and route all HTTP through Req.Test so
# tests can stub github.com responses with `Req.Test.stub(PageDock.Github, ...)`.
config :page_dock, :github,
  client_id: "test-client-id",
  client_secret: "test-client-secret",
  redirect_uri: "http://localhost:4002/auth/github/callback",
  req_options: [plug: {Req.Test, PageDock.Github}]

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
