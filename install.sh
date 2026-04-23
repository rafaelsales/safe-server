#!/bin/bash
# safe-server install script
# Installs the SSH lockdown timer and outbound-tunnel healthcheck.
#
# Usage: sudo ./install.sh
# Env vars (optional, override defaults):
#   SAFE_SERVER_GRACE_MINUTES  - default 60 (1 hour)
#   SAFE_SERVER_PRIVATE_IFACE  - default tailscale0
set -euo pipefail

GRACE_MINUTES="${SAFE_SERVER_GRACE_MINUTES:-60}"
PRIVATE_IFACE="${SAFE_SERVER_PRIVATE_IFACE:-tailscale0}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "error: must be run as root (use sudo)" >&2
  exit 1
fi

# Sanity check: ssh.socket must be the active unit (socket-activated sshd).
if ! systemctl is-enabled --quiet ssh.socket 2>/dev/null; then
  echo "error: ssh.socket is not enabled on this system." >&2
  echo "       safe-server assumes socket-activated sshd. Investigate before proceeding." >&2
  exit 1
fi

# Warn (but don't block) if the private interface is missing right now.
if ! ip link show "$PRIVATE_IFACE" >/dev/null 2>&1; then
  echo "warning: $PRIVATE_IFACE interface not present yet." >&2
  echo "         Bring $PRIVATE_IFACE up before the ${GRACE_MINUTES}-minute timer fires," >&2
  echo "         or the lockdown will abort (safe) and retry on next boot." >&2
fi

echo ">> Writing /etc/safe-server/config.env"
install -d -m 0755 /etc/safe-server
cat > /etc/safe-server/config.env <<EOF
SAFE_SERVER_GRACE_MINUTES=$GRACE_MINUTES
SAFE_SERVER_PRIVATE_IFACE=$PRIVATE_IFACE
EOF

echo ">> Installing binaries to /usr/local/sbin/"
install -m 0755 "$REPO_DIR/bin/safe-server-lockdown"    /usr/local/sbin/safe-server-lockdown
install -m 0755 "$REPO_DIR/bin/safe-server-healthcheck" /usr/local/sbin/safe-server-healthcheck

echo ">> Installing systemd units"
substitute() {
  sed \
    -e "s|@GRACE_MINUTES@|$GRACE_MINUTES|g" \
    -e "s|@PRIVATE_IFACE@|$PRIVATE_IFACE|g" \
    "$1"
}
for unit in safe-server-lockdown.service safe-server-lockdown.timer \
            safe-server-healthcheck.service safe-server-healthcheck.timer; do
  substitute "$REPO_DIR/systemd/$unit" > "/etc/systemd/system/$unit"
  echo "   /etc/systemd/system/$unit"
done

echo ">> Reloading systemd and enabling timers"
systemctl daemon-reload
systemctl enable --now safe-server-lockdown.timer
systemctl enable --now safe-server-healthcheck.timer

echo
echo "Installed. Configuration:"
echo "  Grace window : ${GRACE_MINUTES} minutes"
echo "  Private iface: $PRIVATE_IFACE"
echo "  Uptime now   : $(uptime -p)"
echo
echo "Timer status:"
systemctl list-timers 'safe-server-*.timer' --no-pager || true
echo
echo "Public SSH closes ${GRACE_MINUTES} min from now, and ${GRACE_MINUTES} min after every future boot."
echo "To test immediately:  sudo systemctl start safe-server-lockdown.service"
echo "To undo:              sudo ./uninstall.sh"
