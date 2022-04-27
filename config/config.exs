# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :luhack_vm_service,
  ecto_repos: [LuhackVmService.Repo]

# Configures the endpoint
config :luhack_vm_service, LuhackVmServiceWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: LuhackVmServiceWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: LuhackVmService.PubSub,
  live_view: [signing_salt: "r9WGQGmj"]

config :luhack_vm_service, LuhackVmService.Scheduler,
  jobs: [
    {"@daily", {LuhackVmService.Jobs, :delete_unused, []}},
    {"*/10 * * * *", {LuhackVmService.Jobs, :stop_inactive, []}}
  ]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.29",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :tailwind,
  version: "3.0.24",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.scss
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
