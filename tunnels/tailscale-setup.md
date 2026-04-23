# Tailscale Setup (Private SSH Access)

Tailscale provides the private overlay network that safe-server uses for
ongoing SSH access after the grace window closes.

## Install

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

## Connect to your tailnet

```bash
sudo tailscale up
```

No `--ssh` flag needed. safe-server uses standard SSH keys over the Tailscale
interface; Tailscale SSH is a separate feature and is not required.

## Verify the interface

```bash
ip link show tailscale0
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

Only proceed with `sudo ./install.sh` after this test succeeds.

## Enable exit node or subnet routes (optional)

Not required for safe-server to function. Tailscale's documentation covers
these advanced features at https://tailscale.com/kb/.
