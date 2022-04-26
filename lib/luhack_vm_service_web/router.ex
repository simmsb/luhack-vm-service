defmodule LuhackVmServiceWeb.Router do
  use LuhackVmServiceWeb, :router

  import LuhackVmServiceWeb.UserAuth
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {LuhackVmServiceWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admins_only do
    plug :auth_web
  end

  scope "/", LuhackVmServiceWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/", MainLive, :index
  end


  scope "/" do
    pipe_through [:browser, :admins_only]

    live_dashboard "/dashboard",
      metrics: LuhackVmServiceWeb.Telemetry,
      metrics_history: {LuhackVmService.TelemetryStorage, :metrics_history, []}
  end

  # Other scopes may use custom stacks.
  # scope "/api", LuhackVmServiceWeb do
  #   pipe_through :api
  # end

  ## Authentication routes

  scope "/", LuhackVmServiceWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
  end

  scope "/", LuhackVmServiceWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
  end

  defp auth_web(conn, _opts) do
    admin_pass =
      Application.get_env(:luhack_vm_service, LuhackVmServiceWeb.Router)[:admin_pass]

    with {"admin", provided_pass} <- Plug.BasicAuth.parse_basic_auth(conn),
         true <- Plug.Crypto.secure_compare(provided_pass, admin_pass) do
      conn
    else
      _ -> conn |> Plug.BasicAuth.request_basic_auth() |> halt()
    end
  end
end
