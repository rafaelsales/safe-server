# Architecture & Threat Model

## Core principle

A server with no publicly reachable ports cannot be port-scanned, brute-forced
on SSH, or hit by web exploits against services the operator didn't intend to
expose. Every port that needs to be reachable has a safer alternative that
avoids opening it on the internet:

| Need | Traditional | safe-server way |
|---|---|---|
| Serve HTTP/HTTPS | Open 80/443 to internet | Cloudflare Tunnel (outbound-only) |
| SSH maintenance | Open 22 to internet | Tailscale (private mesh, no open port) |
| Recovery if tunnels fail | — | Reboot to get a 1-hour public SSH window |

## How the SSH lockdown works

This server runs `sshd` in socket-activated mode via `ssh.socket` (default
on Ubuntu 22.04+ and Debian 12+). Socket-activated daemons don't open their
listen socket themselves — systemd holds the socket and passes a connection to
sshd on demand. This lets us change *who sshd listens on* without touching
sshd's config.

We set `BindToDevice=tailscale0` on `ssh.socket` by writing a systemd drop-in
to `/run/systemd/system/ssh.socket.d/safe-server.conf`. `BindToDevice` is a
kernel `SO_BINDTODEVICE` socket option: the kernel only delivers packets that
arrive on the named interface, regardless of IP address. Public internet packets
never reach sshd.

Why not iptables? iptables works, but it:

- Is stateful and survives reboots unless explicitly persisted.
- Has a complex, easy-to-misconfigure rule language.
- Must be kept in sync with any firewalld/nftables setup already present.

The `BindToDevice` drop-in approach has exactly one moving part (a file under
`/run`) that disappears on reboot automatically.

## Boot flow

```
Boot
 └─ ssh.socket starts → listens on 0.0.0.0:22 (public)
 └─ safe-server-lockdown.timer activates (OnActiveSec=60min)
 └─ safe-server-healthcheck.timer activates (OnActiveSec=5min, repeating)

60 minutes later
 └─ safe-server-lockdown.service runs safe-server-lockdown
      ├─ tailscale0 absent? → abort (public SSH stays open, error logged)
      └─ tailscale0 present? → write drop-in → restart ssh.socket
              └─ ssh.socket now BindToDevice=tailscale0 (private-only)

On reboot
 └─ /run is cleared → drop-in gone → ssh.socket back to 0.0.0.0:22
 └─ timers re-arm
```

## Threat model

**What safe-server protects against:**

- Automated SSH brute-force / credential stuffing from the internet.
- Port scanning revealing running services.
- 0-day exploits against cloudflared or tailscaled over the internet
  (neither binds a publicly reachable port; cloudflared is outbound-only).

**What safe-server does NOT protect against:**

- A compromised Tailscale account (attacker gains tailnet membership).
- A compromised Cloudflare account (attacker reroutes the tunnel).
- Malicious code running inside the server.
- Physical access to the machine.

**Failure safety:**

The lockdown script checks for `tailscale0` before applying the drop-in.
If Tailscale is not up at fire time, the lockdown is skipped (logged) and
public SSH remains open until the next boot cycle. This is intentional:
a failed lockdown beats a silent total lockout.

## Healthcheck

`safe-server-healthcheck` runs every 5 minutes and verifies:

1. `tailscaled` is active and `tailscale0` has an IP.
2. `cloudflared` is active and (if the metrics port is reachable) reports ready.

Failures appear in the system journal (`journalctl -u safe-server-healthcheck`).
To hook in notifications (Slack, PagerDuty, email), add an `OnFailure=` target
to `/etc/systemd/system/safe-server-healthcheck.service.d/notify.conf`.
