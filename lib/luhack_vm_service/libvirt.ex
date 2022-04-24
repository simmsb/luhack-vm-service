defmodule LuhackVmService.LibVirt do
  alias LuhackVmService.{Machines, Machines.Machine}
  alias LuhackVmService.Accounts.User

  use Rustler,
    otp_app: :luhack_vm_service,
    crate: :libvirt

  @spec list_doms() :: [LuhackVmService.LibVirt.Domain] | {:error, {:libvirt, binary()}}
  def list_doms(), do: :erlang.nif_error(:nif_not_loaded)

  @spec get_dom(String.t()) :: LuhackVmService.LibVirt.Domain | {:error, {:libvirt, String.t()}}
  def get_dom(_uuid), do: :erlang.nif_error(:nif_not_loaded)

  @spec start_dom(String.t()) :: :ok | {:error, {:libvirt, String.t()}}
  def start_dom(_uuid), do: :erlang.nif_error(:nif_not_loaded)

  @spec stop_dom(String.t()) :: :ok | {:error, {:libvirt, String.t()}}
  def stop_dom(_uuid), do: :erlang.nif_error(:nif_not_loaded)

  @spec delete_dom(String.t()) :: :ok | {:error, {:libvirt, String.t()}}
  def delete_dom(_uuid), do: :erlang.nif_error(:nif_not_loaded)

  @spec get_dom_vnc_port(String.t()) ::
          integer() | {:error, {:libvirt, String.t()} | :no_port_allocated | atom()}
  def get_dom_vnc_port(_uuid), do: :erlang.nif_error(:nif_not_loaded)

  defp make_vm_name(uuid) do
    "luhack_kali_vm_" <> uuid
  end

  defp do_get_dom_vnc_port(uuuid, retry \\ 3)
  defp do_get_dom_vnc_port(_uuid, _retry = 0), do: {:error, :no_vnc_port_found}

  defp do_get_dom_vnc_port(uuid, retry) do
    case get_dom_vnc_port(uuid) do
      {:error, :no_port_allocated} ->
        Process.sleep(1000)
        do_get_dom_vnc_port(uuid, retry - 1)

      {:error, e} ->
        {:error, e}

      port ->
        {:ok, port}
    end
  end

  @spec start_machine(Machine.t()) :: {:ok, integer()} | {:error, any()}
  def start_machine(%Machine{} = machine) do
    with start_dom(machine.uuid),
         {:ok, port} <- do_get_dom_vnc_port(machine.uuid) do
      {:ok, port}
    end
  end

  @spec stop_machine(Machine.t()) :: :ok | {:error, any()}
  def stop_machine(%Machine{} = machine) do
    stop_dom(machine.uuid)
  end

  @spec delete_machine(Machine.t()) :: :ok | {:error, any()}
  def delete_machine(%Machine{} = machine) do
    with :ok <- delete_dom(machine.uuid),
         File.rm(machine.image_path) do
      :ok
    end
  end

  @spec create_machine_for(User.t()) :: {:ok, Machine.t()} | {:error, any()}
  def create_machine_for(%User{} = user) do
    config = Application.fetch_env!(:luhack_vm_service, LuhackVmService.LibVirt.Config)

    uuid = Ecto.UUID.generate()
    vm_name = make_vm_name(uuid)
    image_path = Path.join(config[:image_dir], vm_name <> ".qcow2")
    vnc_pass = for _ <- 1..8, into: "", do: <<Enum.random('0123456789abcdef')>>

    with {_, 0} <-
           System.cmd(
             "qemu-img",
             ~w(create -b #{config[:base_image]} -F qcow2 -f qcow2 #{image_path})
           ),
         {_, 0} <-
           System.cmd(
             "virt-clone",
             ~w(--original-xml=#{config[:xml_file]} -f #{image_path} -n #{vm_name} -u #{uuid} --preserve-data)
           ),
         {_, 0} <-
           System.cmd(
             "virt-xml",
             ~w(#{uuid} --edit all --graphics password=#{vnc_pass})
           ) do
      Machines.create_machine(user, %{
        image_path: image_path,
        last_used: DateTime.utc_now(),
        uuid: uuid,
        vnc_password: vnc_pass
      })
    else
      err -> {:error, err}
    end
  end
end
