defmodule LuhackVmServiceWeb.PageController do
  use LuhackVmServiceWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
