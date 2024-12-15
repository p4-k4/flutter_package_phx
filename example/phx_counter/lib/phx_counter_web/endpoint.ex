defmodule PhxCounterWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :phx_counter

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_phx_counter_key",
    signing_salt: "qkGiZC2E",
    same_site: "Lax"
  ]

  # Add socket handler for counter with debug logging
  socket "/socket", PhxCounterWeb.UserSocket,
    websocket: [
      connect_info: [:x_headers],
      timeout: 45_000,
      transport_log: :debug
    ],
    longpoll: false

  # Serve at "/" the static files from "priv/static" directory.
  plug Plug.Static,
    at: "/",
    from: :phx_counter,
    gzip: false,
    only: PhxCounterWeb.static_paths()

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug PhxCounterWeb.Router
end
