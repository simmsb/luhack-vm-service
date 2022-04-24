defmodule LuhackVmService.Machines.Machine do
  use TypedEctoSchema
  import Ecto.Changeset

  typed_schema "machines" do
    field :image_path, :string, null: false
    field :last_used, :utc_datetime, null: false
    field :uuid, Ecto.UUID, null: false
    field :vnc_password, :string, null: false

    belongs_to :user, LuhackVmService.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(machine, attrs) do
    machine
    |> cast(attrs, [:uuid, :image_path, :last_used, :user_id, :vnc_password])
    |> validate_required([:uuid, :image_path, :last_used, :user_id, :vnc_password])
  end
end
