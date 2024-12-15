defmodule PhoenixTodoWeb.TodoChannel do
  use PhoenixTodoWeb, :channel
  alias PhoenixTodo.Todos
  import Ecto.Query

  @impl true
  def join("todo:list", _payload, socket) do
    todos = from(t in PhoenixTodo.Todos.Todo,
      select: %{
        id: t.id,
        text: t.text,
        completed: t.completed
      }
    ) |> PhoenixTodo.Repo.all()

    # Return todos in the response field with status
    {:ok, %{status: "ok", response: %{todos: todos}}, socket}
  end

  @impl true
  def handle_in("get_todos", _payload, socket) do
    todos = from(t in PhoenixTodo.Todos.Todo,
      select: %{
        id: t.id,
        text: t.text,
        completed: t.completed
      }
    ) |> PhoenixTodo.Repo.all()

    {:reply, {:ok, %{response: %{todos: todos}}}, socket}
  end

  @impl true
  def handle_in("add_todo", %{"text" => text}, socket) do
    case Todos.create_todo(%{text: text, completed: false}) do
      {:ok, todo} ->
        todo_json = %{
          id: todo.id,
          text: todo.text,
          completed: todo.completed
        }
        # Use broadcast! instead of broadcast_from! to include sender
        broadcast!(socket, "todo_added", %{
          event: "todo_added",
          response: %{todo: todo_json}
        })
        {:reply, {:ok, %{response: %{todo: todo_json}}}, socket}
      {:error, _changeset} ->
        {:reply, {:error, %{reason: "Failed to create todo"}}, socket}
    end
  end

  @impl true
  def handle_in("update_todo", %{"id" => id, "completed" => completed}, socket) do
    todo = Todos.get_todo!(id)
    case Todos.update_todo(todo, %{completed: completed}) do
      {:ok, updated_todo} ->
        todo_json = %{
          id: updated_todo.id,
          text: updated_todo.text,
          completed: updated_todo.completed
        }
        # Use broadcast! instead of broadcast_from! to include sender
        broadcast!(socket, "todo_updated", %{
          event: "todo_updated",
          response: %{todo: todo_json}
        })
        {:reply, {:ok, %{response: %{todo: todo_json}}}, socket}
      {:error, _changeset} ->
        {:reply, {:error, %{reason: "Failed to update todo"}}, socket}
    end
  end

  @impl true
  def handle_in("delete_todo", %{"id" => id}, socket) do
    todo = Todos.get_todo!(id)
    case Todos.delete_todo(todo) do
      {:ok, _deleted} ->
        # Use broadcast! instead of broadcast_from! to include sender
        broadcast!(socket, "todo_deleted", %{
          event: "todo_deleted",
          response: %{id: id}
        })
        {:reply, {:ok, %{response: %{id: id}}}, socket}
      {:error, _changeset} ->
        {:reply, {:error, %{reason: "Failed to delete todo"}}, socket}
    end
  end

  # Handle incoming broadcasts
  def handle_out(event, payload, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end
end
