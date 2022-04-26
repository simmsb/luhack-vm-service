# LuhackVmService

Allows people to start up VMs and connect to them

![screenshot](https://user-images.githubusercontent.com/5330444/164998314-2f08c342-32b9-4cce-bac1-7ca96b208185.png)

__note__: This is absolutely not secure, this is designed with the intention to
be run on an airgapped server that only authorized people have access to,
there's no network filtering set up, so VMs can access the host and such. My
threat model is that if someone abuses the system they will simply be told to
fuck off.

## System requirements

- libvirt (virsh)
- postgres

### Docker requirements

You still need libvirt on the host if running the container, because getting
nested libvirt to work is a PITA. But you don't need to set up postgres at least.

- $LUHACK_IMAGE_DIR should be a path that is the same on the host and in the
  container, and should be readable/writeable to the system libvirt daemon.

- $LUHACK_XML_FILE and $LUHACK_IMAGE_BASE should be files at the same location
  on the host and in the container.

## Phoenix stuff

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
