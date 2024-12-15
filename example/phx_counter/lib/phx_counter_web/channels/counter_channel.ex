defmodule PhxCounterWeb.CounterChannel do
  use PhxCounterWeb, :channel

  @impl true
  def join("counter:lobby", _payload, socket) do
    {:ok, assign(socket, :count, 0)}
  end

  @impl true
  def handle_in("increment", _payload, socket) do
    count = socket.assigns.count + 1
    socket = assign(socket, :count, count)
    broadcast!(socket, "count_updated", %{count: count})
    {:reply, {:ok, %{count: count}}, socket}
  end
end
