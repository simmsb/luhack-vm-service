defmodule LuhackVmService.MachinesTest do
  use LuhackVmService.DataCase

  alias LuhackVmService.Machines

  describe "machines" do
    alias LuhackVmService.Machines.Machine

    import LuhackVmService.MachinesFixtures

    @invalid_attrs %{image_path: nil, last_used: nil, uuid: nil}

    test "list_machines/0 returns all machines" do
      machine = machine_fixture()
      assert Machines.list_machines() == [machine]
    end

    test "get_machine!/1 returns the machine with given id" do
      machine = machine_fixture()
      assert Machines.get_machine!(machine.id) == machine
    end

    test "create_machine/1 with valid data creates a machine" do
      valid_attrs = %{image_path: "some image_path", last_used: ~U[2022-04-22 20:15:00Z], uuid: "7488a646-e31f-11e4-aace-600308960662"}

      assert {:ok, %Machine{} = machine} = Machines.create_machine(valid_attrs)
      assert machine.image_path == "some image_path"
      assert machine.last_used == ~U[2022-04-22 20:15:00Z]
      assert machine.uuid == "7488a646-e31f-11e4-aace-600308960662"
    end

    test "create_machine/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Machines.create_machine(@invalid_attrs)
    end

    test "update_machine/2 with valid data updates the machine" do
      machine = machine_fixture()
      update_attrs = %{image_path: "some updated image_path", last_used: ~U[2022-04-23 20:15:00Z], uuid: "7488a646-e31f-11e4-aace-600308960668"}

      assert {:ok, %Machine{} = machine} = Machines.update_machine(machine, update_attrs)
      assert machine.image_path == "some updated image_path"
      assert machine.last_used == ~U[2022-04-23 20:15:00Z]
      assert machine.uuid == "7488a646-e31f-11e4-aace-600308960668"
    end

    test "update_machine/2 with invalid data returns error changeset" do
      machine = machine_fixture()
      assert {:error, %Ecto.Changeset{}} = Machines.update_machine(machine, @invalid_attrs)
      assert machine == Machines.get_machine!(machine.id)
    end

    test "delete_machine/1 deletes the machine" do
      machine = machine_fixture()
      assert {:ok, %Machine{}} = Machines.delete_machine(machine)
      assert_raise Ecto.NoResultsError, fn -> Machines.get_machine!(machine.id) end
    end

    test "change_machine/1 returns a machine changeset" do
      machine = machine_fixture()
      assert %Ecto.Changeset{} = Machines.change_machine(machine)
    end
  end
end
