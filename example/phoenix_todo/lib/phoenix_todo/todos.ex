defmodule PhoenixTodo.Todos do
  @moduledoc """
  The Todos context.
  """

  import Ecto.Query, warn: false
  alias PhoenixTodo.Repo
  alias PhoenixTodo.Todo

  @doc """
  Returns the list of todos.
  """
  def list_todos do
    Repo.all(Todo)
  end

  @doc """
  Gets a single todo.

  Returns nil if the Todo does not exist.
  """
  def get_todo(id), do: Repo.get(Todo, id)

  @doc """
  Gets a single todo.

  Raises `Ecto.NoResultsError` if the Todo does not exist.
  """
  def get_todo!(id), do: Repo.get!(Todo, id)

  @doc """
  Creates a todo.
  """
  def create_todo(attrs \\ %{}) do
    %Todo{}
    |> Todo.changeset(attrs)
    |> Repo.insert()
    |> broadcast(:todo_created)
  end

  @doc """
  Updates a todo.
  """
  def update_todo(%Todo{} = todo, attrs) do
    todo
    |> Todo.changeset(attrs)
    |> Repo.update()
    |> broadcast(:todo_updated)
  end

  @doc """
  Deletes a todo.
  """
  def delete_todo(%Todo{} = todo) do
    Repo.delete(todo)
    |> broadcast(:todo_deleted)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking todo changes.
  """
  def change_todo(%Todo{} = todo, attrs \\ %{}) do
    Todo.changeset(todo, attrs)
  end

  def subscribe do
    Phoenix.PubSub.subscribe(PhoenixTodo.PubSub, "todos")
  end

  defp broadcast({:error, _reason} = error, _event), do: error
  defp broadcast({:ok, todo} = result, event) do
    Phoenix.PubSub.broadcast(PhoenixTodo.PubSub, "todos", {event, todo})
    result
  end
end
