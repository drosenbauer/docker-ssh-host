#!/usr/bin/env bash
# Configures the demo SSH host at container start, then hands off to CMD (sshd).
set -euo pipefail

SSH_USER="${SSH_USER:-svcadmin}"
KEY_DIR=/etc/ssh/host_keys
CONF_DIR=/etc/ssh/sshd_config.d

log() { echo "[entrypoint] $*" >&2; }

is_true() {
    case "${1,,}" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

# --- Host keys: generate once per volume so known_hosts entries stay valid ---
mkdir -p "$KEY_DIR" /run/sshd
for type in ed25519 ecdsa rsa; do
    key="$KEY_DIR/ssh_host_${type}_key"
    if [[ ! -f "$key" ]]; then
        log "Generating $type host key"
        ssh-keygen -q -t "$type" -N '' -f "$key"
    fi
done
chmod 600 "$KEY_DIR"/ssh_host_*_key

# --- Password for the service account ---
if [[ -n "${SSH_PASSWORD_FILE:-}" ]]; then
    SSH_PASSWORD="$(<"$SSH_PASSWORD_FILE")"
fi
if [[ -z "${SSH_PASSWORD:-}" ]]; then
    SSH_PASSWORD='demoP4ss'
    log "WARNING: SSH_PASSWORD not set; using the well-known demo password."
fi
echo "${SSH_USER}:${SSH_PASSWORD}" | chpasswd
unset SSH_PASSWORD

# --- Optional SSH public keys for the service account ---
if [[ -n "${SSH_AUTHORIZED_KEYS:-}" ]]; then
    home="$(getent passwd "$SSH_USER" | cut -d: -f6)"
    install -d -m 700 -o "$SSH_USER" -g "$SSH_USER" "$home/.ssh"
    printf '%s\n' "$SSH_AUTHORIZED_KEYS" > "$home/.ssh/authorized_keys"
    chown "$SSH_USER:$SSH_USER" "$home/.ssh/authorized_keys"
    chmod 600 "$home/.ssh/authorized_keys"
    log "Installed authorized_keys for $SSH_USER"
fi

# --- sudo: password required by default, optionally passwordless ---
if is_true "${SSH_SUDO_NOPASSWD:-false}"; then
    echo "${SSH_USER} ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-service-account
    chmod 440 /etc/sudoers.d/90-service-account
    log "Passwordless sudo enabled for $SSH_USER"
else
    rm -f /etc/sudoers.d/90-service-account
fi

# --- Legacy algorithms for older Java SSH libraries in some connectors ---
if is_true "${SSHD_LEGACY_ALGORITHMS:-false}"; then
    cat > "$CONF_DIR/05-legacy.conf" <<'EOF'
HostKeyAlgorithms +ssh-rsa
PubkeyAcceptedAlgorithms +ssh-rsa
KexAlgorithms +diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1
EOF
    log "Legacy SSH algorithms (ssh-rsa, SHA-1 key exchange) enabled"
else
    rm -f "$CONF_DIR/05-legacy.conf"
fi

/usr/sbin/sshd -t
exec "$@"
