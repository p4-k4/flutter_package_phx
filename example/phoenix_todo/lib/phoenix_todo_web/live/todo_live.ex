defmodule PhoenixTodoWeb.TodoLive do
  use PhoenixTodoWeb, :live_view
  alias PhoenixTodo.Todos
  alias PhoenixTodo.Todo
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to the todos:list topic to receive broadcast events
      Logger.debug("Subscribing to todos:list")
      PhoenixTodoWeb.Endpoint.subscribe("todos:list")
    end

    todos = Todos.list_todos()
    {:ok, assign(socket, todos: todos)}
  end

  @impl true
  def handle_event("save", %{"title" => title}, socket) when byte_size(title) > 0 do
    case Todos.create_todo(%{title: title}) do
      {:ok, todo} ->
        # Only broadcast, don't update state directly
        # State will be updated via handle_info when we receive the broadcast
        todo_json = %{
          id: todo.id,
          title: todo.title,
          completed: todo.completed,
          inserted_at: todo.inserted_at,
          updated_at: todo.updated_at
        }
        Logger.debug("Broadcasting todo_created: #{inspect(todo_json)}")
        PhoenixTodoWeb.Endpoint.broadcast!("todos:list", "todo_created", todo_json)
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_event("save", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    with {id, _} <- Integer.parse(id),
         todo <- Todos.get_todo!(id),
         {:ok, updated_todo} <- Todos.update_todo(todo, %{completed: !todo.completed}) do
      # Only broadcast, don't update state directly
      todo_json = %{
        id: updated_todo.id,
        title: updated_todo.title,
        completed: updated_todo.completed,
        inserted_at: updated_todo.inserted_at,
        updated_at: updated_todo.updated_at
      }
      Logger.debug("Broadcasting todo_updated: #{inspect(todo_json)}")
      PhoenixTodoWeb.Endpoint.broadcast!("todos:list", "todo_updated", todo_json)
      {:noreply, socket}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    with {id, _} <- Integer.parse(id),
         todo <- Todos.get_todo!(id),
         {:ok, deleted_todo} <- Todos.delete_todo(todo) do
      # Only broadcast, don't update state directly
      todo_json = %{
        id: deleted_todo.id,
        title: deleted_todo.title,
        completed: deleted_todo.completed,
        inserted_at: deleted_todo.inserted_at,
        updated_at: deleted_todo.updated_at
      }
      Logger.debug("Broadcasting todo_deleted: #{inspect(todo_json)}")
      PhoenixTodoWeb.Endpoint.broadcast!("todos:list", "todo_deleted", todo_json)
      {:noreply, socket}
    else
      _ -> {:noreply, socket}
    end
  end

  # Handle broadcast events from all clients (including self)
  @impl true
  def handle_info(%{event: "todo_created", payload: todo}, socket) do
    Logger.debug("Received todo_created: #{inspect(todo)}")
    {:noreply, assign(socket, :todos, [struct(Todo, Map.new(todo)) | socket.assigns.todos])}
  end

  def handle_info(%{event: "todo_updated", payload: updated_todo}, socket) do
    Logger.debug("Received todo_updated: #{inspect(updated_todo)}")
    todos = Enum.map(socket.assigns.todos, fn todo ->
      if todo.id == updated_todo.id, do: struct(Todo, Map.new(updated_todo)), else: todo
    end)
    {:noreply, assign(socket, :todos, todos)}
  end

  def handle_info(%{event: "todo_deleted", payload: deleted_todo}, socket) do
    Logger.debug("Received todo_deleted: #{inspect(deleted_todo)}")
    todos = Enum.reject(socket.assigns.todos, &(&1.id == deleted_todo.id))
    {:noreply, assign(socket, :todos, todos)}
  end
end
