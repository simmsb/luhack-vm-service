defmodule LuhackVmService.Machines do
  @moduledoc """
  The Machines context.
  """

  import Ecto.Query, warn: false
  alias LuhackVmService.Repo

  alias LuhackVmService.Accounts.User
  alias LuhackVmService.Machines.Machine

  @doc """
  Returns the list of machines.

  ## Examples

      iex> list_machines()
      [%Machine{}, ...]

  """
  def list_machines do
    Repo.all(Machine)
  end

  @doc """
  Gets a single machine.

  Raises `Ecto.NoResultsError` if the Machine does not exist.

  ## Examples

      iex> get_machine!(123)
      %Machine{}

      iex> get_machine!(456)
      ** (Ecto.NoResultsError)

  """
  def get_machine!(id), do: Repo.get!(Machine, id)

  def get_machine_by_uuid(uuid), do: Repo.get_by!(Machine, uuid: uuid)

  @spec get_machine_for_user(User.t()) :: Machine.t() | nil
  def get_machine_for_user(%User{} = user), do: Repo.one(Ecto.assoc(user, :machine))

  @doc """
  Creates a machine.

  ## Examples

      iex> create_machine(me, %{field: value})
      {:ok, %Machine{}}

      iex> create_machine(me, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_machine(%User{} = user, attrs \\ %{}) do
    Ecto.build_assoc(user, :machine)
    |> Machine.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a machine.

  ## Examples

      iex> update_machine(machine, %{field: new_value})
      {:ok, %Machine{}}

      iex> update_machine(machine, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_machine(%Machine{} = machine, attrs) do
    machine
    |> Machine.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a machine.

  ## Examples

      iex> delete_machine(machine)
      {:ok, %Machine{}}

      iex> delete_machine(machine)
      {:error, %Ecto.Changeset{}}

  """
  def delete_machine(%Machine{} = machine) do
    Repo.delete(machine)
  end

  def touch_machine(%Machine{} = machine) do
    update_machine(machine, %{last_used: DateTime.utc_now()})
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking machine changes.

  ## Examples

      iex> change_machine(machine)
      %Ecto.Changeset{data: %Machine{}}

  """
  def change_machine(%Machine{} = machine, attrs \\ %{}) do
    Machine.changeset(machine, attrs)
  end

  def inactive_machines do
    Machine
    |> where([m], m.last_used < datetime_add(^DateTime.utc_now(), -10, "minute"))
    |> Repo.all()
  end

  def unused_machines do
    Machine
    |> where([m], m.last_used < datetime_add(^DateTime.utc_now(), -1, "month"))
    |> Repo.all()
  end
end
