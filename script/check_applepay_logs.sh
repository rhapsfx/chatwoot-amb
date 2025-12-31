#!/bin/bash
# Check bot logs for Apple Pay errors in conversation 6

echo "======================================================================="
echo "🔍 CHECKING APPLE PAY LOGS FOR CONVERSATION 6"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "Recent Apple Pay related logs (last 200 lines):"
echo "---"
docker compose -f docker-compose.production.yml logs --tail=200 web 2>/dev/null | \
  grep -i "apple.*pay\|conversation.*6\|sendapplepay\|merchant.*session\|payment.*gateway" | \
  tail -50

echo ""
echo "---"
echo ""
echo "Apple Pay specific errors:"
docker compose -f docker-compose.production.yml logs --tail=500 web 2>/dev/null | \
  grep -i "AMB ApplePay.*error\|ApplePay.*failed\|payment.*error" | \
  tail -20
REMOTE_SCRIPT

echo ""
echo "======================================================================="
