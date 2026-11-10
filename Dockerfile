# syntax=docker/dockerfile:1

# Demo SSH target for IGA Linux/Unix connectors.
# NOT for production use.

FROM debian:trixie-slim

ARG SSH_USER=svcadmin
ARG SSH_UID=1005

LABEL org.opencontainers.image.title="docker-ssh-host" \
      org.opencontainers.image.description="Demo SSH host for IGA Linux/Unix connector testing. Not for production." \
      org.opencontainers.image.base.name="docker.io/library/debian:trixie-slim"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        openssh-server \
        sudo \
        nano \
        less \
        procps \
 && rm -rf /var/lib/apt/lists/* \
 # Host keys are generated per container at startup, never baked into the image.
 && rm -f /etc/ssh/ssh_host_* \
 # Accounts created by the connector default to bash, not sh.
 && sed -i 's|^#\?\s*SHELL=.*|SHELL=/bin/bash|' /etc/default/useradd \
 && groupadd --gid "${SSH_UID}" "${SSH_USER}" \
 && useradd --no-log-init --create-home --shell /bin/bash \
        --uid "${SSH_UID}" --gid "${SSH_USER}" --groups sudo "${SSH_USER}"

COPY sshd_config.d/ /etc/ssh/sshd_config.d/
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENV SSH_USER=${SSH_USER}

# Persist host keys here so clients' known_hosts survive container re-creation.
VOLUME ["/etc/ssh/host_keys"]

EXPOSE 22

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD bash -c '</dev/tcp/127.0.0.1/22' || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
