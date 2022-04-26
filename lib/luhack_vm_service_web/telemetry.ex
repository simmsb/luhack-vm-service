defmodule LuhackVmServiceWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
      {LuhackVmService.TelemetryStorage, metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defmodule LuhackVmServiceWeb.Telemetry.Fns do
    def put_lv_meta(metadata) do
      Map.put(metadata, :view, "#{inspect(metadata.socket.view)}")
    end
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Live View Metrics
      summary("phoenix.live_view.mount.stop.duration",
        tags: [:view],
        tag_values: &LuhackVmServiceWeb.Telemetry.Fns.put_lv_meta/1,
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_view.handle_params.stop.duration",
        tags: [:view],
        tag_values: &LuhackVmServiceWeb.Telemetry.Fns.put_lv_meta/1,
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_view.handle_event.stop.duration",
        tags: [:view, :event],
        tag_values: &LuhackVmServiceWeb.Telemetry.Fns.put_lv_meta/1,
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("luhack_vm_service.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("luhack_vm_service.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("luhack_vm_service.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("luhack_vm_service.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("luhack_vm_service.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {LuhackVmServiceWeb, :count_users, []}
    ]
  end
end
