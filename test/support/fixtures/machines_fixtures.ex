defmodule LuhackVmService.MachinesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LuhackVmService.Machines` context.
  """

  @doc """
  Generate a machine.
  """
  def machine_fixture(attrs \\ %{}) do
    {:ok, machine} =
      attrs
      |> Enum.into(%{
        image_path: "some image_path",
        last_used: ~U[2022-04-22 20:15:00Z],
        uuid: "7488a646-e31f-11e4-aace-600308960662"
      })
      |> LuhackVmService.Machines.create_machine()

    machine
  end
end
