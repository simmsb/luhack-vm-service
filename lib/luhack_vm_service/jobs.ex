defmodule LuhackVmService.Jobs do
  alias LuhackVmService.{Machines, LibVirt}

  require Logger

  def delete_unused do
    num_deleted =
      for machine <- Machines.unused_machines() do
        LibVirt.delete_machine(machine)
      end
      |> Enum.count()

    Logger.info("Deleted #{num_deleted} unused machines")
  end

  def stop_inactive do
    {:ok, doms} = LibVirt.list_doms()

    running_machines =
      doms
      |> Enum.filter(fn dom -> dom.state == :running end)
      |> Enum.map(fn dom -> dom.uuid end)
      |> Enum.into(MapSet.new())

    num_stopped =
      for machine <- Machines.inactive_machines(),
          MapSet.member?(running_machines, machine.uuid) do
        LibVirt.stop_machine(machine)
      end
      |> Enum.count()

    Logger.info("Stopped #{num_stopped} inactive machines")
  end
end
