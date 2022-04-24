defmodule LuhackVmService.VncWorker do
  use Task, restart: :transient
  require Logger

  def start_link([vnc_port, listen_port]) do
    Task.start_link(__MODULE__, :run, [vnc_port, listen_port])
  end

  def run(vnc_port, listen_port) do
    Logger.info("Starting up vnc process with vnc_port: #{vnc_port}, listen_port: #{listen_port}")

    MuonTrap.cmd("novnc", ~w(--vnc localhost:#{vnc_port} --listen #{listen_port} --idle-timeout 10))
  end
end
