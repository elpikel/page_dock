import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/page_dock start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :page_dock, PageDockWeb.Endpoint, server: true
end

config :page_dock, PageDockWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# GitHub OAuth (account linking). Register an OAuth App at
# https://github.com/settings/developers and set these env vars. The callback
# URL configured on GitHub must match GITHUB_REDIRECT_URI. Skipped in :test,
# which stubs GitHub via Req.Test (see config/test.exs).
if config_env() != :test do
  config :page_dock, :github,
    client_id: System.get_env("GITHUB_CLIENT_ID"),
    client_secret: System.get_env("GITHUB_CLIENT_SECRET"),
    redirect_uri:
      System.get_env("GITHUB_REDIRECT_URI") ||
        "http://localhost:4000/auth/github/callback"
end

# Public base URL that GitHub uses to deliver webhooks. Locally this is your
# tunnel (e.g. an ngrok https URL); GitHub cannot reach localhost directly.
# Registered webhooks become `<WEBHOOK_BASE_URL>/webhooks/github/<site_id>`.
if webhook_base_url = System.get_env("WEBHOOK_BASE_URL") do
  config :page_dock, :sites, webhook_base_url: webhook_base_url
end

# Where published site files live on disk. In production this MUST be an absolute
# path outside the release directory (e.g. /var/lib/pagedock/deploys) so deploys
# survive app upgrades. Defaults to priv/deploys (fine for dev only).
if deploy_root = System.get_env("DEPLOY_ROOT") do
  config :page_dock, :sites, deploy_root: deploy_root
end

# Cloak vault: encrypts sensitive columns (e.g. GitHub tokens) at rest.
# CLOAK_KEY is a base64-encoded 32-byte key (generate with
# `Base.encode64(:crypto.strong_rand_bytes(32))`). A fixed key is used in
# dev/test only; production must supply its own and keep it stable.
cloak_key =
  System.get_env("CLOAK_KEY") ||
    if config_env() == :prod do
      raise """
      environment variable CLOAK_KEY is missing.
      Generate one with: mix run -e 'IO.puts(Base.encode64(:crypto.strong_rand_bytes(32)))'
      """
    else
      "zNOg1xOSPT2PjVIPoG00gmwx1D4Sgwxe/4EW4/34dMY="
    end

config :page_dock, PageDock.Vault,
  ciphers: [
    default:
      {Cloak.Ciphers.AES.GCM, tag: "AES.GCM.V1", key: Base.decode64!(cloak_key), iv_length: 12}
  ]

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :page_dock, PageDock.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :page_dock, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :page_dock, PageDockWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :page_dock, PageDockWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :page_dock, PageDockWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :page_dock, PageDock.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
