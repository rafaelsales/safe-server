#!/bin/bash
# safe-server uninstall script
# Completely removes the safe-server setup and restores public SSH.
#
# Run as root: sudo ./uninstall.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "error: must be run as root (use sudo)" >&2
  exit 1
fi

echo ">> Disabling and stopping safe-server timers and services"
for unit in safe-server-lockdown.timer safe-server-healthcheck.timer \
            safe-server-lockdown.service safe-server-healthcheck.service; do
  systemctl disable --now "$unit" 2>/dev/null || true
done

echo ">> Removing systemd units"
for unit in safe-server-lockdown.service safe-server-lockdown.timer \
            safe-server-healthcheck.service safe-server-healthcheck.timer; do
  rm -f "/etc/systemd/system/$unit"
done

echo ">> Removing binaries"
rm -f /usr/local/sbin/safe-server-lockdown
rm -f /usr/local/sbin/safe-server-healthcheck

echo ">> Removing configuration"
rm -rf /etc/safe-server

echo ">> Removing active ssh.socket drop-in (if any)"
rm -f /run/systemd/system/ssh.socket.d/safe-server.conf
rmdir /run/systemd/system/ssh.socket.d 2>/dev/null || true

echo ">> Reloading systemd and restarting ssh.socket"
systemctl daemon-reload
systemctl restart ssh.socket

echo
echo "Uninstalled. Current ssh.socket listeners:"
ss -tlnp 2>/dev/null | awk 'NR==1 || /:22 /'
echo
echo "Public SSH is restored on 0.0.0.0:22."
