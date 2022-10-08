defmodule LuhackVmService.Repo.Migrations.RemoveVncPass do
  use Ecto.Migration

  def change do
    alter table(:machines) do
      remove :vnc_password
    end
  end
end
