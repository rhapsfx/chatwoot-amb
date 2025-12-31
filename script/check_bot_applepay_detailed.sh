#!/bin/bash
# Check bot-specific Apple Pay logs with detailed output

echo "======================================================================="
echo "🤖 BOT APPLE PAY DETAILED LOGS"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "Looking for bot Apple Pay logs (last attempt)..."
echo ""

# Get the most recent bot Apple Pay attempt
docker compose -f docker-compose.production.yml logs --tail=1000 web 2>/dev/null | \
  grep -E "\[Bot\].*💳|\[AMB ApplePay\]|SendApplePayService|Apple Pay demo" | \
  tail -50

echo ""
echo "---"
echo ""
echo "Looking for ANY errors in last 100 log lines:"
docker compose -f docker-compose.production.yml logs --tail=100 web 2>/dev/null | \
  grep -i "error\|exception\|failed" | \
  tail -20

REMOTE_SCRIPT

echo ""
echo "======================================================================="
