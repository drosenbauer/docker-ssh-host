## SSH Host container

A small Debian 13 (trixie) image that runs an SSH server, for demoing and testing identity governance connectors that manage Linux accounts over SSH.

> **POC and demo use only.** This image ships with a well-known default password and a sudo-capable account. Do not expose it to untrusted networks or use it in production.

### Quick start

```bash
docker compose up -d --build
```

Then connect on port 2222:

```bash
ssh -p 2222 svcadmin@localhost
```

The service account is `svcadmin` (UID 1005), a member of `sudo`. If you don't set a password, it's `demoP4ss` and the container logs a warning at startup.

Without Compose:

```bash
docker build -t docker-ssh-host .
docker run -d --name ssh-host -p 2222:22 -v ssh-host-keys:/etc/ssh/host_keys docker-ssh-host
```

### Configuration

All settings are read at container start, so you can change them without rebuilding.

| Variable | Default | Purpose |
| --- | --- | --- |
| `SSH_PASSWORD` | `demoP4ss` | Password for the `svcadmin` account. |
| `SSH_PASSWORD_FILE` | — | Read the password from a file instead (e.g. a Docker secret). Takes precedence over `SSH_PASSWORD`. |
| `SSH_AUTHORIZED_KEYS` | — | Newline-separated SSH public keys for `svcadmin`. |
| `SSH_SUDO_NOPASSWD` | `false` | `true` lets `svcadmin` use sudo without a password. By default sudo prompts for the password, which matches how most connectors are configured. |
| `SSHD_LEGACY_ALGORITHMS` | `false` | `true` re-enables `ssh-rsa` (SHA-1) host and user keys and SHA-1 key exchange. Turn this on only if an older connector's Java SSH library fails with "no matching host key type" or a key exchange error. |

Build arguments `SSH_USER` and `SSH_UID` change the account name and UID.

With Compose, put the variables in a `.env` file next to `compose.yaml`:

```dotenv
SSH_PASSWORD=something-better
SSH_SUDO_NOPASSWD=true
```

### Behavior notes

- **Host keys** are generated on the container's first start and stored in `/etc/ssh/host_keys`. Mount a volume there (Compose does this for you) so the connector's known-hosts entry stays valid when the container is recreated. Delete the volume to rotate the keys.
- **New accounts get bash.** `useradd` defaults to `/bin/bash`, so accounts the connector creates have a usable shell.
- **Root login over SSH is disabled.** Use `svcadmin` plus sudo.
- **Logs** go to `docker logs`, including sshd's auth log.
- A **health check** reports the container healthy once sshd accepts TCP connections.
