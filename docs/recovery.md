# Recovery Procedures

## Locked out of SSH?

After the grace window closes, SSH is restricted to the Tailscale interface.
If you can't reach the server via Tailscale, the recovery path is always a
**reboot**. A reboot clears the `/run` drop-in and restores public SSH for
another full grace window (default: 1 hour).

### Reboot options by environment

| Environment | How to reboot |
|---|---|
| AWS EC2 | EC2 console → Instances → Actions → Reboot Instance |
| DigitalOcean Droplet | Control panel → Power → Reboot |
| Hetzner VPS | Cloud console → Power → Restart |
| Linode | Cloud manager → Reboot |
| Physical / bare-metal | Provider's IPMI/iDRAC/iLO console, or physical power button |
| Any VPS with serial console | Serial console → `sudo reboot` |

After the reboot:

1. Public SSH will be open on port 22 for the grace window duration.
2. Diagnose why Tailscale/Cloudflare Tunnel failed using that window.
3. Fix the issue, verify the private interface is up (`ip link show tailscale0`).
4. The lockdown timer will fire again automatically after the grace window.

## Immediate undo (without reboot)

If you have any access to the machine (serial console, KVM, another tunnel):

```bash
# Remove the active drop-in and restore public SSH
sudo rm -f /run/systemd/system/ssh.socket.d/safe-server.conf
sudo systemctl daemon-reload
sudo systemctl restart ssh.socket
```

## Permanently remove safe-server

If you want to stop safe-server entirely:

```bash
sudo ./uninstall.sh
```

This disables the timers, removes the units and binaries, and restores
`ssh.socket` to its default configuration.

## Manually trigger lockdown for testing

```bash
sudo systemctl start safe-server-lockdown.service
```

Check the result:

```bash
# Should show BindToDevice=tailscale0
systemctl show ssh.socket -p BindToDevice

# Should show no 0.0.0.0:22 listener
ss -tlnp | grep :22
```

## Check healthcheck status

```bash
# Recent healthcheck output
journalctl -u safe-server-healthcheck --since "1 hour ago"

# Run it manually
sudo systemctl start safe-server-healthcheck.service
journalctl -u safe-server-healthcheck -n 30
```
