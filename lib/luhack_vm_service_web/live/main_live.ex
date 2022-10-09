defmodule LuhackVmServiceWeb.MainLive do
  use LuhackVmServiceWeb, :live_view

  require Logger

  alias LuhackVmService.{Machines, Repo, LibVirt, Accounts.UserToken}
  alias LuhackVmService.Accounts

  @impl true
  def mount(_params, %{"user_token" => user_token} = _session, socket) do
    user = Accounts.get_user_by_session_token(user_token)

    socket =
      socket
      |> assign(current_user: user, vnc_addr: nil,
                width: 1024, height: 768)
      |> refresh_machine()

    :timer.send_interval(5000, self(), :tick)

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

    if user.machine do
      Machines.touch_machine(user.machine)
    end

    machine_state =
      user.machine &&
        with {:ok, dom} <- LibVirt.get_dom(user.machine.uuid) do
          dom
        else
          _ -> nil
        end

    socket =
      if machine_state && machine_state.state == :running do
        do_novnc_stuff(socket, machine_state.uuid)
      else
        socket
      end

    socket
    |> assign(current_user: user, machine_state: machine_state)
  end

  defp do_novnc_stuff(socket, _uuid) when socket.assigns.vnc_addr != nil do
    socket
  end

  defp do_novnc_stuff(socket, uuid) do
    socket = stop_vnc_session(socket)

    token = Phoenix.Token.sign(LuhackVmServiceWeb.Endpoint, "vnc auth", uuid)

    vnc_uri =
      Routes.static_url(socket, "/spice-web-client/index.html")
      |> URI.parse()

    vnc_addr =
      vnc_uri
      |> Map.put(
        :query,
        URI.encode_query(%{
          host: vnc_uri.host,
          port: vnc_uri.port,
          path: "/vnc/websocket?token=#{token}",
          autoconnect: true,
          reconnect: true,
          resize: "scale"
        })
      )
      |> URI.to_string()

    Logger.info("Generated vnc addr: #{vnc_addr}")

    socket
    |> assign(vnc_addr: vnc_addr)
  end

  defp stop_vnc_session(socket) do
    socket
    |> assign(vnc_addr: nil)
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

  @impl true
  def handle_event("sync-size", %{"height" => height, "width" => width}, socket) do
    Logger.debug("Setting client size to #{width}:#{height}")

    socket =
      socket
      |> assign(width: width, height: height)

    {:noreply, socket}
  end
end
