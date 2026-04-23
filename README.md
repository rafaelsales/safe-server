# safe-server

> No ports exposed to the internet. Zero attack surface.

safe-server is an opinionated set of scripts and systemd units that enforce a
single security posture: **your server has no publicly reachable ports**. All
access goes through outbound-only tunnels.

```
Internet user → Cloudflare edge → cloudflared tunnel → your app
You (SSH)     → Tailscale mesh → tailscale0 interface → sshd
Recovery      → Reboot → 1-hour public SSH window → fix tunnels → locked again
```

## How it works

| Layer | Tool | What it does |
|---|---|---|
| Content (HTTP/S) | Cloudflare Tunnel | Outbound-only; no port 80/443 open |
| Maintenance (SSH) | Tailscale | Private mesh; no port 22 open (after grace window) |
| Bootstrap/Recovery | safe-server-lockdown | Public SSH open for 1h after boot, then closed automatically |
| Watchdog | safe-server-healthcheck | Verifies both tunnels are healthy every 5 min |

The SSH lockdown uses `BindToDevice=tailscale0` on `ssh.socket` via a systemd
drop-in written to `/run/` — it disappears on reboot, giving a fresh grace
window every time the machine starts. No iptables rules, no persistent firewall
state.

## Requirements

- Ubuntu 22.04+ or Debian 12+ (socket-activated sshd via `ssh.socket`).
- [Tailscale](tunnels/tailscale-setup.md) installed and connected.
- [cloudflared](tunnels/cloudflared-setup.md) installed and configured (for the healthcheck; Cloudflare Tunnel is optional but recommended).
- `sudo` / root access for install.

## Install

```bash
# Clone the repo
git clone https://github.com/rafaelsales/safe-server.git
cd safe-server

# Set up Tailscale first and verify SSH works over it, then:
sudo ./install.sh

# Optional: override defaults
sudo SAFE_SERVER_GRACE_MINUTES=120 ./install.sh
```

### What install.sh does

1. Checks that `ssh.socket` is enabled (socket-activated sshd).
2. Warns if `tailscale0` is not yet present.
3. Writes configuration to `/etc/safe-server/config.env`.
4. Installs binaries to `/usr/local/sbin/`.
5. Installs systemd units to `/etc/systemd/system/`.
6. Enables both timers immediately.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `SAFE_SERVER_GRACE_MINUTES` | `60` | Minutes of public SSH after each boot |
| `SAFE_SERVER_PRIVATE_IFACE` | `tailscale0` | Interface SSH is restricted to |

Stored at `/etc/safe-server/config.env` after install.

## Verify

```bash
# Check timers are armed
systemctl list-timers 'safe-server-*.timer'

# Before lockdown fires: public SSH is reachable
ss -tlnp | grep :22    # shows 0.0.0.0:22

# Manually trigger lockdown (Tailscale must be up)
sudo systemctl start safe-server-lockdown.service

# After lockdown: interface-bound only
systemctl show ssh.socket -p BindToDevice    # BindToDevice=tailscale0

# Check healthcheck logs
journalctl -u safe-server-healthcheck -n 20
```

## Uninstall

```bash
sudo ./uninstall.sh
```

Disables all timers, removes units and binaries, restores `ssh.socket` to
listen on `0.0.0.0:22`.

## Recovery

If you're locked out: **reboot the server** via your cloud/VPS dashboard,
physical console, or IPMI. A reboot clears the `/run` drop-in and restores
public SSH for a fresh grace window.

See [docs/recovery.md](docs/recovery.md) for platform-specific instructions.

## Architecture & threat model

See [docs/architecture.md](docs/architecture.md).

## FAQ

**Why not iptables?**
iptables rules persist across service restarts and have complex interaction with
firewalld/nftables. The `BindToDevice` drop-in lives under `/run/` and vanishes
on reboot with zero configuration drift.

**What if Tailscale fails after lockdown?**
Public SSH is closed until reboot. The lockdown script checks for `tailscale0`
before applying the drop-in — if Tailscale wasn't up at fire time, the lockdown
was skipped and public SSH remained open.

**What if I need longer than 1 hour to bootstrap?**
Set `SAFE_SERVER_GRACE_MINUTES=120` (or any value) at install time.

**Does this affect IPv6?**
`BindToDevice` is interface-based, not protocol-based. It covers both IPv4 and
IPv6 traffic on `ssh.socket`.

**Does `ssh localhost` still work after lockdown?**
No. `BindToDevice=tailscale0` also blocks loopback. SSH to the Tailscale IP
(`tailscale ip -4`) works fine.

## License

MIT — see [LICENSE](LICENSE).
