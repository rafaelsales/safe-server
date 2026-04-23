# Changelog

## v0.1.0 — 2026-04-23

Initial release.

- SSH lockdown timer: restricts `ssh.socket` to Tailscale interface after a
  configurable grace window (default 1 hour per boot).
- Outbound-tunnel healthcheck: verifies `tailscaled` and `cloudflared` are
  healthy every 5 minutes, reports failures to the system journal.
- Install/uninstall scripts with env-var configuration.
- Systemd unit templates with `@GRACE_MINUTES@` and `@PRIVATE_IFACE@`
  substitution.
- Setup guides for Tailscale and Cloudflare Tunnel.
- Architecture, threat model, and recovery documentation.
- CI: shellcheck + shfmt + smoke tests.
