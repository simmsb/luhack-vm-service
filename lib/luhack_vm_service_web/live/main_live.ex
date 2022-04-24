defmodule LuhackVmServiceWeb.MainLive do
  use LuhackVmServiceWeb, :live_view

  require Logger

  alias LuhackVmService.{Machines, Repo, LibVirt}
  alias LuhackVmService.Accounts

  @impl true
  def mount(_params, %{"user_token" => user_token} = _session, socket) do
    user = Accounts.get_user_by_session_token(user_token)

    socket =
      socket
      |> assign(current_user: user, vnc_addr: nil, vnc_pid: nil)
      |> refresh_machine()

    :timer.send_interval(1000, self(), :tick)

    {:ok, socket}
  end

  @impl true
  def handle_info(:tick, socket) do
    {:noreply, refresh_machine(socket)}
  end

  defp refresh_machine(socket) do
    user =
      Repo.reload(socket.assigns.current_user)
      |> Accounts.with_machine()

    machine_state =
      user.machine &&
        with {:ok, dom} <- LibVirt.get_dom(user.machine.uuid) do
          dom
        else
          _ -> nil
        end

    socket =
      if machine_state && machine_state.state == :running do
        with {:ok, port} <- LibVirt.vnc_port_of(user.machine) do
          do_novnc_stuff(socket, port, user.machine.vnc_password)
        else
          _ -> socket
        end
      else
        socket
      end

    socket
    |> assign(current_user: user, machine_state: machine_state)
  end

  # this is a hack, ideally we'd do the proxying ourselves
  # we'd then also be able to eliminate vnc passwords, as we'd just authenticate in the websocket
  defp generate_listen_port() do
    {:ok, port} = :gen_tcp.listen(0, [])
    {:ok, port_number} = :inet.port(port)
    Port.close(port)

    port_number
  end

  defp do_novnc_stuff(socket, _vnc_port, _password) when socket.assigns.vnc_addr != nil do
    socket
  end

  defp do_novnc_stuff(socket, vnc_port, vnc_password) do
    socket = stop_vnc_session(socket)

    listen_port = generate_listen_port()

    Logger.info("Got listen port: #{listen_port}")

    {:ok, pid} =
      Supervisor.start_link([{LuhackVmService.VncWorker, [vnc_port, listen_port]}],
        strategy: :one_for_one
      )

    # give the vnc proxy a while to start up
    Process.sleep(300)

    vnc_addr =
      Routes.url(socket)
      |> URI.parse()
      |> Map.put(:port, listen_port)
      |> Map.put(:path, "/vnc.html")
      |> Map.put(
        :query,
        URI.encode_query(%{
          host: "localhost",
          port: listen_port,
          password: vnc_password,
          autoconnect: true,
          reconnect: true,
          resize: "scale"
        })
      )
      |> URI.to_string()

    Logger.info("Generated vnc addr: #{vnc_addr}")

    socket
    |> assign(vnc_addr: vnc_addr, vnc_pid: pid)
  end

  defp stop_vnc_session(socket) do
    with pid when pid != nil <- socket.assigns.vnc_pid do
      Supervisor.stop(pid)
    end

    socket
    |> assign(vnc_addr: nil, vnc_pid: nil)
  end

  @impl true
  def handle_event("start_or_create", _params, socket) do
    machine = Machines.get_machine_for_user(socket.assigns.current_user)

    machine =
      if machine == nil do
        Logger.info("Creating machine")
        {:ok, machine} = LibVirt.create_machine_for(socket.assigns.current_user)
        machine
      else
        machine
      end

    LibVirt.start_machine(machine)

    socket =
      socket
      |> refresh_machine()

    {:noreply, socket}
  end

  @impl true
  def handle_event("restart", _params, socket) do
    socket = stop_vnc_session(socket)

    with machine when machine != nil <-
           Machines.get_machine_for_user(socket.assigns.current_user),
         :ok <- LibVirt.stop_machine(machine),
         :ok <- LibVirt.start_machine_nowait(machine) do
      Logger.info("Restarting domain", %{uuid: machine.uuid})

      socket =
        socket
        |> put_flash(:info, "Restarting vm")
        |> refresh_machine()

      {:noreply, socket}
    else
      err ->
        Logger.error("Failed to restart domain", %{err: err})

        socket =
          socket
          |> put_flash(:error, "Restarting vm failed???")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("shut_down", _params, socket) do
    socket = stop_vnc_session(socket)

    with machine when machine != nil <-
           Machines.get_machine_for_user(socket.assigns.current_user),
         :ok <- LibVirt.stop_machine(machine) do
      Logger.info("Stopping domain", %{uuid: machine.uuid})

      socket =
        socket
        |> put_flash(:info, "Stopped vm")
        |> refresh_machine()

      {:noreply, socket}
    else
      err ->
        Logger.error("Failed to stop domain", %{err: err})

        socket =
          socket
          |> put_flash(:error, "Stopping vm failed???")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    socket = stop_vnc_session(socket)

    with machine when machine != nil <-
           Machines.get_machine_for_user(socket.assigns.current_user),
         :ok <- LibVirt.delete_machine(machine) do
      Logger.info("Deleted domain", %{uuid: machine.uuid})

      socket =
        socket
        |> put_flash(:info, "Deleted vm")
        |> refresh_machine()

      {:noreply, socket}
    else
      err ->
        Logger.error("Failed to delete domain", %{err: err})

        socket =
          socket
          |> put_flash(:error, "Deleting domain failed???")

        {:noreply, socket}
    end
  end
end
