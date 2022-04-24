defmodule LuhackVmServiceWeb.MainLive do
  use LuhackVmServiceWeb, :live_view

  alias LuhackVmService.{Machines, Machine}
  alias LuhackVmService.Accounts

  @impl true
  def mount(_params, %{"user_token" => user_token} = _session, socket) do
    user =
      Accounts.get_user_by_session_token(user_token)
      |> Accounts.with_machine()

    socket =
      socket
      |> assign(current_user: user)

    {:ok, socket}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
  end

  defp apply_action(socket, :new, _params) do
    socket
  end

  defp apply_action(socket, :index, _params) do
    socket
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply, socket}
  end
end
