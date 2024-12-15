defmodule PhoenixTodoWeb.UserSocket do
  use Phoenix.Socket

  require Logger

  # A Socket handler
  #
  # It's possible to control the websocket connection and
  # assign values that can be accessed by your channel topics.

  ## Channels
  channel "todos:*", PhoenixTodoWeb.TodoChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error` or `{:error, term}`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(params, socket, connect_info) do
    Logger.debug("Socket connect params: #{inspect(params)}")
    Logger.debug("Socket connect info: #{inspect(connect_info)}")
    {:ok, socket}
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.PhoenixTodoWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(_socket), do: nil

  # Support both V1 and V2 serializers
  def serializer do
    [{Phoenix.Socket.V2.JSONSerializer, "~> 2.0.0"},
     {Phoenix.Socket.V1.JSONSerializer, "~> 1.0.0"}]
  end
end
