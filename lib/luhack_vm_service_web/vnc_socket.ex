defmodule LuhackVmServiceWeb.VncSocket do
  @moduledoc """
  Proxy vnc data
  """

  require Logger

  @behaviour Phoenix.Socket.Transport

  def child_spec(_opts) do
    # We won't spawn any process, so let's return a dummy task
    %{id: Task, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  def connect(%{params: %{"token" => token}} = _transport_info) do
    {:ok, uuid} = Phoenix.Token.verify(LuhackVmServiceWeb.Endpoint, "vnc auth", token)
    Logger.info("Starting up vnc socket #{uuid}")
    {:ok, uuid}
  end

  def init(uuid) do
    {:ok, port} = LuhackVmService.LibVirt.vnc_port_of(uuid)
    {:ok, sock} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: true])

    {:ok, sock}
  end

  def handle_info({:tcp, _, data}, state) do
    {:push, {:binary, data}, state}
  end

  def handle_in({msg, [opcode: :binary]}, state) do
    :ok = :gen_tcp.send(state, msg)

    {:ok, state}
  end

  def handle_in({msg, [opcode: opcode]}, state) do
    Logger.warn("Unexpected message to socket: #{opcode}: #{msg}")

    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
