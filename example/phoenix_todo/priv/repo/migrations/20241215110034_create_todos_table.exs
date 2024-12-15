defmodule PhoenixTodo.Repo.Migrations.CreateTodosTable do
  use Ecto.Migration

  def change do
    # Drop the existing table first
    drop_if_exists table(:todos)

    create table(:todos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :text, :string, null: false
      add :completed, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
