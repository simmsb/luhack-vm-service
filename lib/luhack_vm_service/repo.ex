defmodule LuhackVmService.Repo do
  use Ecto.Repo,
    otp_app: :luhack_vm_service,
    adapter: Ecto.Adapters.Postgres
end
