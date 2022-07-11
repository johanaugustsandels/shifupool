import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# Start the phoenix server if environment is set and running in a release
if System.get_env("PHX_SERVER") && System.get_env("RELEASE_NAME") do
  config :bmbpool, BmbpoolWeb.Endpoint, server: true
end

if config_env() == :prod do
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
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :bmbpool, BmbpoolWeb.Endpoint,
    url: [host: host, port: 443],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
      config :bmbpool, BmbpoolWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.
end

fee = System.get_env("SHIFUPOOL_FEE_PERCENT","4") |>Integer.parse()|>elem(0)
if fee<0 || fee>50 do
  raise "Invalid value for SHIFUPOO_FEE_PERCENT"
end
config :bmbpool, 
    address: System.get_env("SHIFUPOOL_PAYOUT_ADDRESS","BE5E70FDBCDFE84FD46B841731C218C43DA7C92BAFE0E349B75EC4ECEB3D7B55"),
    pool_port: System.get_env("SHIFUPOOL_POOL_PORT","5555")|>Integer.parse()|>elem(0),
    pufferfish_height: System.get_env("SHIFUPOOL_PUFFERFISH_HEIGHT","124501")|>Integer.parse()|>elem(0),
    backend_port: System.get_env("SHIFUPOOL_BACKEND_PORT","4002")|>Integer.parse()|>elem(0),
    round_blocks: System.get_env("SHIFUPOOL_ROUND_BLOCKS","1500") |>Integer.parse()|>elem(0),
    payoutdelay_blocks: System.get_env("SHIFUPOOL_PAYOUTDELAY_BLOCKS","150") |>Integer.parse()|>elem(0),
    pool_host: System.get_env("SHIFUPOOL_HOST","185.215.180.7"),
    nodes: String.split(System.get_env("SHIFUPOOL_NODES", "http://173.230.139.86:3001|http://173.230.139.86:3002|http://173.230.139.86:3000"),"|"),
    fee: fee

