defmodule LuhackVmService.Machines.Machine do
  use TypedEctoSchema
  import Ecto.Changeset

  typed_schema "machines" do
    field :image_path, :string, null: false
    field :last_used, :utc_datetime, null: false
    field :uuid, Ecto.UUID, null: false

    belongs_to :user, LuhackVmService.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(machine, attrs) do
    machine
    |> cast(attrs, [:uuid, :image_path, :last_used, :user_id])
    |> validate_required([:uuid, :image_path, :last_used, :user_id])
  end
end
