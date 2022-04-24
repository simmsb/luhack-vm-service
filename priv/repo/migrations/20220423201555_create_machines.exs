defmodule LuhackVmService.Repo.Migrations.CreateMachines do
  use Ecto.Migration

  def change do
    create table(:machines) do
      add :uuid, :uuid, null: false
      add :image_path, :string, null: false
      add :last_used, :utc_datetime, null: false
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :vnc_password, :string, null: false

      timestamps()
    end

    create index(:machines, [:user_id])
    create index(:machines, [:uuid])
  end
end
