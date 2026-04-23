# Cloudflare Tunnel Setup (Outbound-Only HTTP/HTTPS)

Cloudflare Tunnel (`cloudflared`) lets your server serve HTTP/HTTPS content
without opening any inbound port. The tunnel connects outbound to Cloudflare's
edge and Cloudflare proxies public traffic back over it.

## Prerequisites

- A domain managed by Cloudflare (free plan works).
- A Cloudflare account.

## Install cloudflared

Download and install `cloudflared` from the [official Linux downloads page](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/downloads/#linux).

## Authenticate with Cloudflare

```bash
cloudflared tunnel login
```

This opens a browser to authorize cloudflared against your Cloudflare account
and downloads a credentials certificate.

## Create a tunnel

```bash
cloudflared tunnel create my-server
```

Note the tunnel UUID from the output.

## Configure the tunnel

Create `/etc/cloudflared/config.yml`:

```yaml
tunnel: <tunnel-uuid>
credentials-file: /root/.cloudflared/<tunnel-uuid>.json

ingress:
  - hostname: app.yourdomain.com
    service: http://localhost:3000
  - hostname: www.yourdomain.com
    service: http://localhost:80
  - service: http_status:404
```

## Add DNS records

```bash
cloudflared tunnel route dns my-server app.yourdomain.com
cloudflared tunnel route dns my-server www.yourdomain.com
```

## Run as a systemd service

```bash
sudo cloudflared service install
sudo systemctl enable --now cloudflared
```

## Verify

```bash
systemctl is-active cloudflared
curl -sf http://127.0.0.1:2000/ready && echo "tunnel ready"
```

The safe-server healthcheck will pick up cloudflared's status automatically.

## Firewall reminder

With the tunnel running, you can block inbound 80 and 443 at the OS firewall
or cloud security group. Traffic flows: browser → Cloudflare edge → outbound
tunnel → local service. No inbound HTTP port needed.
