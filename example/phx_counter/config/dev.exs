import Config

# For development, we disable any cache and enable
# debugging and code reloading.
config :phx_counter, PhxCounterWeb.Endpoint,
  # Binding to all network interfaces
  http: [ip: {0, 0, 0, 0}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "HkOH36kZvlMoZ4UIrtiiIL9Mj9h6WxBbQTGWDRJqPjPYDywPmRZ6U7dxzXZxBpfi",
  watchers: [],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/phx_counter_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20
