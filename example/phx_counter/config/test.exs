import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :phx_counter, PhxCounterWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "juubGWwRultupW5L6SCVIEx2woqwmOhKgEDnd7Zt3fKrOQrG8vTud0eqw4IS6dht",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
