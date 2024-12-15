defmodule PhoenixTodoWeb.TodoChannel do
  use PhoenixTodoWeb, :channel
  alias PhoenixTodo.Todos
  require Logger

  @impl true
  def join("todos:list", _payload, socket) do
    Logger.debug("Joining todos:list channel")
    todos = Todos.list_todos()
    # Convert todos to maps for proper JSON serialization
    todos_json = Enum.map(todos, fn todo ->
      %{
        id: todo.id,
        title: todo.title,
        completed: todo.completed,
        inserted_at: todo.inserted_at,
        updated_at: todo.updated_at
      }
    end)
    {:ok, %{todos: todos_json}, socket}
  end

  @impl true
  def handle_in("event", %{"event" => "new_todo", "title" => title}, socket) do
    Logger.debug("Creating new todo: #{title}")
    case Todos.create_todo(%{title: title, completed: false}) do
      {:ok, todo} ->
        todo_json = %{
          id: todo.id,
          title: todo.title,
          completed: todo.completed,
          inserted_at: todo.inserted_at,
          updated_at: todo.updated_at
        }
        # Broadcast to all clients including the sender
        broadcast!(socket, "todo_created", todo_json)
        {:reply, {:ok, todo_json}, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
    end
  end

  def handle_in("event", %{"event" => "update_todo", "id" => id, "completed" => completed}, socket) do
    Logger.debug("Updating todo #{id} completed: #{completed}")

    # Skip database update for temporary IDs
    if String.starts_with?(id, "temp_") do
      todo_json = %{
        id: id,
        completed: completed
      }
      broadcast!(socket, "todo_updated", todo_json)
      {:reply, {:ok, todo_json}, socket}
    else
      case get_and_update_todo(id, %{completed: completed}) do
        {:ok, todo_json} ->
          broadcast!(socket, "todo_updated", todo_json)
          {:reply, {:ok, todo_json}, socket}
        {:error, reason} ->
          {:reply, {:error, %{message: reason}}, socket}
      end
    end
  end

  def handle_in("event", %{"event" => "delete_todo", "id" => id}, socket) do
    Logger.debug("Deleting todo #{id}")

    # For temporary IDs, just broadcast the deletion without database operation
    if String.starts_with?(id, "temp_") do
      broadcast!(socket, "todo_deleted", %{id: id})
      {:reply, {:ok, %{id: id}}, socket}
    else
      case get_and_delete_todo(id) do
        {:ok, todo_json} ->
          broadcast!(socket, "todo_deleted", todo_json)
          {:reply, {:ok, todo_json}, socket}
        {:error, reason} ->
          {:reply, {:error, %{message: reason}}, socket}
      end
    end
  end

  # Handle any other events
  def handle_in(event, payload, socket) do
    Logger.debug("Unhandled event #{event} with payload: #{inspect(payload)}")
    {:noreply, socket}
  end

  # Helper functions to safely handle database operations
  defp get_and_update_todo(id, attrs) do
    with {id, _} <- Integer.parse(id),
         todo when not is_nil(todo) <- Todos.get_todo(id),
         {:ok, updated_todo} <- Todos.update_todo(todo, attrs) do
      {:ok, %{
        id: updated_todo.id,
        title: updated_todo.title,
        completed: updated_todo.completed,
        inserted_at: updated_todo.inserted_at,
        updated_at: updated_todo.updated_at
      }}
    else
      :error -> {:error, "Invalid ID format"}
      nil -> {:error, "Todo not found"}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  defp get_and_delete_todo(id) do
    with {id, _} <- Integer.parse(id),
         todo when not is_nil(todo) <- Todos.get_todo(id),
         {:ok, deleted_todo} <- Todos.delete_todo(todo) do
      {:ok, %{
        id: deleted_todo.id,
        title: deleted_todo.title,
        completed: deleted_todo.completed,
        inserted_at: deleted_todo.inserted_at,
        updated_at: deleted_todo.updated_at
      }}
    else
      :error -> {:error, "Invalid ID format"}
      nil -> {:error, "Todo not found"}
      {:error, _} -> {:error, "Failed to delete todo"}
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
