# Tailscale Setup (Private SSH Access)

Tailscale provides the private overlay network that safe-server uses for
ongoing SSH access after the grace window closes.

## Install

Follow the [official Linux instructions](https://tailscale.com/docs/install/linux).

## Connect to your tailnet

```bash
sudo tailscale up --ssh
```

## Verify the interface

```bash
ip addr show tailscale0
```

The interface must have an IP address before safe-server's lockdown fires.

## Test SSH via Tailscale before arming

From a **different machine on the same tailnet**, verify SSH works via the
Tailscale IP or MagicDNS name:

```bash
# Find your Tailscale IP
tailscale ip -4

# From another machine on the tailnet
ssh ubuntu@<tailscale-ip>
# or
ssh ubuntu@<machine-hostname>
```

Only proceed with `sudo ./install.sh` after this test succeeds — it's your
fallback if public SSH closes.
