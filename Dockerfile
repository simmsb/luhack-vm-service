# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian instead of
# Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20220801-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.13.4-erlang-24.3.3-debian-bullseye-20210902-slim
#
ARG ELIXIR_VERSION=1.14.0
ARG OTP_VERSION=25.1
ARG DEBIAN_VERSION=bullseye-20220801-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y --no-install-recommends libvirt-dev build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# set up rust

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH \
    RUST_VERSION=1.64.0

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        gcc \
        libc6-dev \
        wget \
        ; \
    dpkgArch="$(dpkg --print-architecture)"; \
    case "${dpkgArch##*-}" in \
        amd64) rustArch='x86_64-unknown-linux-gnu'; rustupSha256='5cc9ffd1026e82e7fb2eec2121ad71f4b0f044e88bca39207b3f6b769aaa799c' ;; \
        armhf) rustArch='armv7-unknown-linux-gnueabihf'; rustupSha256='48c5ecfd1409da93164af20cf4ac2c6f00688b15eb6ba65047f654060c844d85' ;; \
        arm64) rustArch='aarch64-unknown-linux-gnu'; rustupSha256='e189948e396d47254103a49c987e7fb0e5dd8e34b200aa4481ecc4b8e41fb929' ;; \
        i386) rustArch='i686-unknown-linux-gnu'; rustupSha256='0e0be29c560ad958ba52fcf06b3ea04435cb3cd674fbe11ce7d954093b9504fd' ;; \
        *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;; \
    esac; \
    url="https://static.rust-lang.org/rustup/archive/1.25.1/${rustArch}/rustup-init"; \
    wget "$url"; \
    echo "${rustupSha256} *rustup-init" | sha256sum -c -; \
    chmod +x rustup-init; \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain $RUST_VERSION --default-host ${rustArch}; \
    rm rustup-init; \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME; \
    rustup --version; \
    cargo --version; \
    rustc --version; \
    apt-get remove -y --auto-remove \
        wget \
        ; \
    rm -rf /var/lib/apt/lists/*;

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY native native

COPY priv priv

COPY lib lib

COPY assets assets

# compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile


# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}
LABEL org.opencontainers.image.source https://github.com/simmsb/luhack

RUN apt-get update -y && apt-get install -y --no-install-recommends \
    libstdc++6 openssl libncurses5 locales \
    libvirt-daemon-system libvirt-clients qemu-system qemu-utils virtinst \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*


# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV container docker
ENV DEBIAN_FRONTEND noninteractive
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done);
# RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
#             /etc/systemd/system/*.wants/* \
#             /lib/systemd/system/local-fs.target.wants/* \
#             /lib/systemd/system/sockets.target.wants/*udev* \
#             /lib/systemd/system/sockets.target.wants/*initctl* \
#             /lib/systemd/system/basic.target.wants/* \
#             /lib/systemd/system/anaconda.target.wants/* \
#             /lib/systemd/system/plymouth* \
#             /lib/systemd/system/systemd-update-utmp*
# VOLUME [/sys/fs/cgroup]

# RUN systemctl enable libvirtd; systemctl enable virtlockd

# RUN echo "listen_tls = 0" >> /etc/libvirt/libvirtd.conf; \
#     echo 'listen_tcp = 1' >> /etc/libvirt/libvirtd.conf; \
#     echo 'tls_port = "16514"' >> /etc/libvirt/libvirtd.conf; \
#     echo 'tcp_port = "16509"' >> /etc/libvirt/libvirtd.conf; \
#     echo 'auth_tcp = "none"' >> /etc/libvirt/libvirtd.conf

# RUN echo 'vnc_listen = "0.0.0.0"' >> /etc/libvirt/qemu.conf

# # RUN echo 'LIBVIRTD_ARGS="--listen"' >> /etc/sysconfig/libvirtd

# ADD customlibvirtpost.service /usr/lib/systemd/system/customlibvirtpost.service
# ADD customlibvirtpost.sh /customlibvirtpost.sh
# RUN chmod a+x /customlibvirtpost.sh
# ADD network.xml /network.xml
# RUN systemctl enable customlibvirtpost

WORKDIR "/app"

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder /app/_build/${MIX_ENV}/rel/luhack_vm_service ./

# ENTRYPOINT ["/bin/sh"]

CMD ["/app/bin/server"]
