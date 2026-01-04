# Cloudflare Tunnel Deployment for rAthena AI Sidecar

**Deployment Date:** 2026-01-04  
**Status:** ✅ Active and Running  
**Service:** `cloudflared-rathena.service`

---

## 🔑 Tunnel Configuration Details

### Tunnel Information
- **Tunnel Name:** `rathena-ai-sidecar`
- **Tunnel ID:** `0f79854f-4cab-4840-9047-4ed24925f9bf`
- **Target Service:** `https://rathena.cakobox.com` (rAthena AI World Sidecar FastAPI Server)
- **Public Hostname:** `rathena.cakobox.com`
- **CNAME Target:** `0f79854f-4cab-4840-9047-4ed24925f9bf.cfargotunnel.com`

### Edge Locations
The tunnel has established connections to the following Cloudflare edge locations:
- 2x Kuala Lumpur (kul01)
- 1x Singapore (sin07)
- 1x Singapore (sin12)

---

## 📁 File Locations

### Configuration Files
```
/etc/cloudflared/rathena-ai-sidecar.yml              # Tunnel configuration
/etc/cloudflared/rathena-ai-sidecar-credentials.json # Tunnel credentials (600 permissions)
/etc/cloudflared/cert.pem                            # Cloudflare origin certificate
```

### Credentials Backup
```
/home/lot399/.cloudflared/0f79854f-4cab-4840-9047-4ed24925f9bf.json  # Backup credentials
```

### Service File
```
/etc/systemd/system/cloudflared-rathena.service      # Systemd service definition
```

---

## ⚙️ Configuration

### Tunnel Configuration (`/etc/cloudflared/rathena-ai-sidecar.yml`)
```yaml
tunnel: 0f79854f-4cab-4840-9047-4ed24925f9bf
credentials-file: /etc/cloudflared/rathena-ai-sidecar-credentials.json

ingress:
  - hostname: rathena.cakobox.com
    service: https://rathena.cakobox.com
  - service: http_status:404

metrics: localhost:9299
loglevel: info
```

### Systemd Service Configuration
```ini
[Unit]
Description=Cloudflare Tunnel for rAthena AI Sidecar
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel --config /etc/cloudflared/rathena-ai-sidecar.yml run rathena-ai-sidecar
Restart=on-failure
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
```

---

## 🌐 DNS Configuration Required

### Manual DNS Setup in Cloudflare Dashboard

**⚠️ IMPORTANT:** You must manually add the following DNS record in your Cloudflare dashboard:

1. Log in to Cloudflare Dashboard: https://dash.cloudflare.com
2. Select domain: `cakobox.com`
3. Go to **DNS** → **Records**
4. Click **Add record**
5. Configure as follows:

```
Type:    CNAME
Name:    rathena
Target:  0f79854f-4cab-4840-9047-4ed24925f9bf.cfargotunnel.com
Proxy:   ✅ Proxied (orange cloud)
TTL:     Auto
```

6. Click **Save**

### Verification
After DNS propagation (usually 1-5 minutes), verify with:
```bash
dig rathena.cakobox.com CNAME +short
# Should return: 0f79854f-4cab-4840-9047-4ed24925f9bf.cfargotunnel.com
```

---

## 🚀 Service Management

### Service Commands
```bash
# Check service status
sudo systemctl status cloudflared-rathena.service

# View logs in real-time
sudo journalctl -u cloudflared-rathena.service -f

# View last 100 log lines
sudo journalctl -u cloudflared-rathena.service -n 100 --no-pager

# Restart service
sudo systemctl restart cloudflared-rathena.service

# Stop service
sudo systemctl stop cloudflared-rathena.service

# Start service
sudo systemctl start cloudflared-rathena.service

# Disable auto-start on boot
sudo systemctl disable cloudflared-rathena.service

# Enable auto-start on boot
sudo systemctl enable cloudflared-rathena.service
```

### Tunnel Management Commands
```bash
# List all tunnels
cloudflared tunnel list

# Get tunnel info
cloudflared tunnel info rathena-ai-sidecar

# Test tunnel configuration
cloudflared tunnel --config /etc/cloudflared/rathena-ai-sidecar.yml run rathena-ai-sidecar
```

---

## 🧪 Testing & Verification

### Local Testing (AI Sidecar Server)
```bash
# Test root endpoint
curl https://rathena.cakobox.com/

# Expected response:
# {
#   "service": "rAthena AI World Sidecar",
#   "version": "1.0.0",
#   "status": "online",
#   "docs": "/docs",
#   "api": "/api/v1"
# }

# Test docs endpoint
curl https://rathena.cakobox.com/docs
```

### Public Testing (After DNS Setup)
```bash
# Test root endpoint via tunnel
curl https://rathena.cakobox.com/

# Test docs endpoint
curl https://rathena.cakobox.com/docs

# Test with browser
firefox https://rathena.cakobox.com/docs
```

### Tunnel Connectivity Check
```bash
# Check tunnel connections
cloudflared tunnel info rathena-ai-sidecar

# Check service status
sudo systemctl is-active cloudflared-rathena.service

# Check metrics
curl http://localhost:9299/metrics
```

---

## 🔒 Security Considerations

### ✅ Security Measures in Place
1. **API Authentication**: AI Sidecar requires `X-API-Key` header for API endpoints
2. **Local Binding**: AI Sidecar binds to `0.0.0.0:8765` but proxied through Cloudflare
3. **Tunnel Encryption**: All traffic encrypted via Cloudflare tunnel (TLS)
4. **Credential Protection**: Credentials file has 600 permissions (root only)
5. **Service Isolation**: Runs as systemd service with restart policies

### 🛡️ Additional Security Recommendations
1. **Monitor Logs**: Regularly check logs for unusual activity
   ```bash
   sudo journalctl -u cloudflared-rathena.service --since "1 hour ago" | grep -i error
   ```

2. **Firewall Rules**: Ensure port 8765 is NOT directly exposed to internet
   ```bash
   sudo netstat -tlnp | grep 8765
   # Should show: 0.0.0.0:8765 (proxied via Cloudflare, not directly accessible)
   ```

3. **Rate Limiting**: Consider enabling Cloudflare rate limiting for the domain

4. **API Key Rotation**: Periodically rotate API keys used by AI Sidecar

---

## 📊 Monitoring

### Metrics Endpoint
The tunnel exposes metrics at: `http://localhost:9299/metrics`

### Key Metrics to Monitor
- Tunnel connection status
- Request count
- Error rates
- Latency metrics

### Log Locations
```bash
# Systemd journal
sudo journalctl -u cloudflared-rathena.service

# Filter by date
sudo journalctl -u cloudflared-rathena.service --since "2026-01-04"

# Filter by priority (errors only)
sudo journalctl -u cloudflared-rathena.service -p err
```

---

## 🔄 Rollback Instructions

### To Stop and Disable the Tunnel
```bash
# Stop the service
sudo systemctl stop cloudflared-rathena.service

# Disable auto-start
sudo systemctl disable cloudflared-rathena.service

# Remove DNS record from Cloudflare dashboard
# (Go to DNS settings and delete the rathena CNAME record)
```

### To Completely Remove the Tunnel
```bash
# Stop and disable service
sudo systemctl stop cloudflared-rathena.service
sudo systemctl disable cloudflared-rathena.service

# Delete tunnel (CAUTION: This is permanent!)
cloudflared tunnel delete rathena-ai-sidecar

# Remove configuration files
sudo rm /etc/cloudflared/rathena-ai-sidecar.yml
sudo rm /etc/cloudflared/rathena-ai-sidecar-credentials.json
sudo rm /home/lot399/.cloudflared/0f79854f-4cab-4840-9047-4ed24925f9bf.json

# Remove systemd service file
sudo rm /etc/systemd/system/cloudflared-rathena.service
sudo systemctl daemon-reload
```

---

## 🐛 Troubleshooting

### Issue: Tunnel Not Connecting
```bash
# Check service status
sudo systemctl status cloudflared-rathena.service

# Check logs for errors
sudo journalctl -u cloudflared-rathena.service -n 50 --no-pager

# Test configuration manually
sudo cloudflared tunnel --config /etc/cloudflared/rathena-ai-sidecar.yml run rathena-ai-sidecar
```

### Issue: DNS Not Resolving
```bash
# Check DNS record
dig rathena.cakobox.com +short

# Check CNAME
dig rathena.cakobox.com CNAME +short

# Wait 1-5 minutes for DNS propagation
# Or flush local DNS cache:
sudo systemd-resolve --flush-caches
```

### Issue: 502 Bad Gateway
This means tunnel is working but AI Sidecar server is down.

```bash
# Check if AI Sidecar is running
netstat -tlnp | grep 8765

# Test locally
curl https://rathena.cakobox.com/

# Check AI Sidecar logs
# (Check wherever your AI Sidecar logs are located)
```

### Issue: Tunnel Registered but No Connections
```bash
# Check for firewall blocking
sudo ufw status

# Restart the service
sudo systemctl restart cloudflared-rathena.service

# Check cloudflared version
cloudflared --version
```

---

## 📝 Existing Infrastructure

### Other Services (Not Modified)
The existing Cloudflare tunnel (`openkore-central` - ef0bd1c4-13a0-427d-ba25-56a0b9365dc0) continues to run independently with these services:
- `openkore-ai.com` → http://localhost:3000
- `www.openkore-ai.com` → http://localhost:3000
- `api.openkore-ai.com` → http://localhost:8080
- `telemetry.openkore-ai.com` → http://localhost:8080
- `social.cakobox.com` → http://localhost:10301

**Configuration:** `/etc/cloudflared/config.yml`  
**Service:** `cloudflared.service` and `cloudflared-openkore.service`

---

## ✅ Deployment Summary

| Component | Status | Details |
|-----------|--------|---------|
| Tunnel Created | ✅ | `rathena-ai-sidecar` (0f79854f-4cab-4840-9047-4ed24925f9bf) |
| Configuration File | ✅ | `/etc/cloudflared/rathena-ai-sidecar.yml` |
| Credentials File | ✅ | `/etc/cloudflared/rathena-ai-sidecar-credentials.json` |
| Systemd Service | ✅ | `cloudflared-rathena.service` (enabled & running) |
| Service Status | ✅ | Active with 4 edge connections |
| AI Sidecar Server | ✅ | Running on https://rathena.cakobox.com |
| DNS Configuration | ⚠️ | **Manual setup required in Cloudflare dashboard** |
| Metrics Endpoint | ✅ | http://localhost:9299/metrics |

---

## 📞 Next Steps

1. ✅ **Tunnel is running** - Service active and healthy
2. ⚠️ **Configure DNS** - Add CNAME record in Cloudflare dashboard (see DNS Configuration section)
3. ⏳ **Wait for DNS propagation** - Usually 1-5 minutes
4. ✅ **Test public access** - `curl https://rathena.cakobox.com/`
5. ✅ **Monitor logs** - Ensure no errors in production
6. 📊 **Set up monitoring** - Consider adding uptime monitoring for the endpoint

---

## 📚 Additional Resources

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Cloudflared GitHub Repository](https://github.com/cloudflare/cloudflared)
- [Systemd Service Documentation](https://www.freedesktop.org/software/systemd/man/systemd.service.html)

---

**Deployment Completed:** 2026-01-04 17:38:54 +08  
**Cloudflared Version:** 2025.11.1  
**Operating System:** Linux 6.14.0-37-generic (Ubuntu 24.04)
