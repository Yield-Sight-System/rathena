#!/bin/bash
# Test script for rAthena Cloudflare Tunnel
# Run this after DNS is configured

echo "========================================"
echo "rAthena Cloudflare Tunnel Test Script"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Check tunnel service status
echo -n "1. Checking tunnel service status... "
if systemctl is-active --quiet cloudflared-rathena.service; then
    echo -e "${GREEN}✓ RUNNING${NC}"
else
    echo -e "${RED}✗ NOT RUNNING${NC}"
    echo "   Run: sudo systemctl start cloudflared-rathena.service"
fi

# Test 2: Check AI Sidecar local status
echo -n "2. Checking AI Sidecar (https://rathena.cakobox.com)... "
if curl -s -o /dev/null -w "%{http_code}" https://rathena.cakobox.com/ | grep -q "200"; then
    echo -e "${GREEN}✓ ONLINE${NC}"
else
    echo -e "${RED}✗ OFFLINE${NC}"
    echo "   AI Sidecar server not running on port 8765"
fi

# Test 3: Check tunnel info
echo -n "3. Checking tunnel registration... "
if cloudflared tunnel info rathena-ai-sidecar &>/dev/null; then
    echo -e "${GREEN}✓ REGISTERED${NC}"
else
    echo -e "${RED}✗ NOT FOUND${NC}"
fi

# Test 4: Check tunnel connections
echo "4. Checking tunnel connections..."
CONNECTIONS=$(cloudflared tunnel info rathena-ai-sidecar 2>/dev/null | grep -A1 "CONNECTOR ID" | tail -1 | awk '{print $NF}')
if [ ! -z "$CONNECTIONS" ]; then
    echo -e "   ${GREEN}✓ Connected: $CONNECTIONS${NC}"
else
    echo -e "   ${YELLOW}⚠ No active connections${NC}"
fi

# Test 5: Check DNS resolution
echo -n "5. Checking DNS resolution (rathena.cakobox.com)... "
DNS_RESULT=$(dig +short rathena.cakobox.com 2>/dev/null | head -1)
if [ ! -z "$DNS_RESULT" ]; then
    echo -e "${GREEN}✓ RESOLVED${NC}"
    echo "   IP: $DNS_RESULT"
else
    echo -e "${YELLOW}⚠ NOT CONFIGURED${NC}"
    echo "   Add CNAME record in Cloudflare dashboard:"
    echo "   Name: rathena"
    echo "   Target: 0f79854f-4cab-4840-9047-4ed24925f9bf.cfargotunnel.com"
fi

# Test 6: Check CNAME record
echo -n "6. Checking CNAME record... "
CNAME_RESULT=$(dig +short rathena.cakobox.com CNAME 2>/dev/null)
if echo "$CNAME_RESULT" | grep -q "cfargotunnel.com"; then
    echo -e "${GREEN}✓ CORRECT${NC}"
    echo "   Target: $CNAME_RESULT"
else
    echo -e "${YELLOW}⚠ NOT SET${NC}"
    echo "   Expected: 0f79854f-4cab-4840-9047-4ed24925f9bf.cfargotunnel.com"
fi

# Test 7: Check public access (root endpoint)
echo -n "7. Testing public access (https://rathena.cakobox.com/)... "
if [ ! -z "$DNS_RESULT" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://rathena.cakobox.com/ 2>/dev/null)
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ SUCCESS (HTTP $HTTP_CODE)${NC}"
    else
        echo -e "${RED}✗ FAILED (HTTP $HTTP_CODE)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ SKIPPED (DNS not configured)${NC}"
fi

# Test 8: Check docs endpoint
echo -n "8. Testing docs endpoint (https://rathena.cakobox.com/docs)... "
if [ ! -z "$DNS_RESULT" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://rathena.cakobox.com/docs 2>/dev/null)
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ SUCCESS (HTTP $HTTP_CODE)${NC}"
    else
        echo -e "${RED}✗ FAILED (HTTP $HTTP_CODE)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ SKIPPED (DNS not configured)${NC}"
fi

# Test 9: Check metrics endpoint
echo -n "9. Checking metrics endpoint (localhost:9299)... "
if curl -s -o /dev/null -w "%{http_code}" http://localhost:9299/metrics | grep -q "200"; then
    echo -e "${GREEN}✓ AVAILABLE${NC}"
else
    echo -e "${YELLOW}⚠ NOT AVAILABLE${NC}"
fi

# Test 10: Check systemd service logs
echo "10. Recent service logs (last 5 lines):"
sudo journalctl -u cloudflared-rathena.service -n 5 --no-pager 2>/dev/null | sed 's/^/    /'

echo ""
echo "========================================"
echo "Test Complete!"
echo "========================================"
echo ""
echo "Configuration Details:"
echo "  Tunnel ID: 0f79854f-4cab-4840-9047-4ed24925f9bf"
echo "  Tunnel Name: rathena-ai-sidecar"
echo "  Public URL: https://rathena.cakobox.com"
echo "  Local Service: https://rathena.cakobox.com"
echo "  Metrics: http://localhost:9299/metrics"
echo ""
echo "For more information, see: CLOUDFLARE_TUNNEL_RATHENA_DEPLOYMENT.md"
