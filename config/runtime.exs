import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/luhack_vm_service start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :luhack_vm_service, LuhackVmServiceWeb.Endpoint, server: true
end

xml_file =
  System.get_env("LUHACK_XML_FILE") ||
    raise """
    environment variable LUHACK_XML_FILE is missing.
    point this to domain xml file
    """

if !File.exists?(xml_file) do
  raise """
  The LUHACK_XML_FILE #{xml_file} doesn't seem to exist
  """
end

base_image =
  System.get_env("LUHACK_BASE_IMAGE") ||
    raise """
    environment variable LUHACK_BASE_IMAGE is missing.
    point this to the vm base image
    """

if !File.exists?(base_image) do
  raise """
  The LUHACK_BASE_IMAGE #{base_image} doesn't seem to exist
  """
end

image_dir =
  System.get_env("LUHACK_IMAGE_DIR") ||
    raise """
    environment variable LUHACK_IMAGE_DIR is missing.
    point this to a directory to place images
    """

if !File.exists?(image_dir) do
  raise """
  The LUHACK_IMAGE_DIR #{image_dir} doesn't seem to exist
  """
end

admin_pass =
  System.get_env("ADMIN_PASS") ||
    raise """
    environment variable ADMIN_PASS is missing.
    set this to a password for the admin interface
    """

config :luhack_vm_service, LuhackVmServiceWeb.Router, admin_pass: admin_pass

config :luhack_vm_service, LuhackVmService.LibVirt.Config,
  xml_file: xml_file,
  base_image: base_image,
  image_dir: image_dir

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  config :luhack_vm_service, LuhackVmService.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  scheme = System.get_env("PHX_SCHEME") || "http"
  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4000")
  ext_port = String.to_integer(System.get_env("PHX_PORT") || "4000")

  config :luhack_vm_service, LuhackVmServiceWeb.Endpoint,
    url: [scheme: scheme, host: host, port: ext_port],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 1},
      port: port,
      compress: true
    ],

    # we run behind a reverse proxy
    check_origin: false,
    secret_key_base: secret_key_base
end
