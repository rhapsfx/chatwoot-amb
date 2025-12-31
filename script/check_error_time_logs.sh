#!/bin/bash
# Check logs around 14:14:10 UTC for the error

echo "======================================================================="
echo "🔍 LOGS AROUND 14:14:10 UTC (Maps error)"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "Looking for logs between 14:13:00 and 14:15:00 UTC..."
echo ""

docker compose -f docker-compose.production.yml logs --since 2025-11-25T14:13:00Z --until 2025-11-25T14:15:00Z web 2>/dev/null | \
  grep -E "Bot.*handle|AppleMapsService|geocod|location_response|conversation.*6|ERROR" | \
  grep -v "INFO -- : \[RailsLogger\]"

echo ""
echo "---"
echo ""
echo "Any exceptions in that timeframe:"
docker compose -f docker-compose.production.yml logs --since 2025-11-25T14:13:00Z --until 2025-11-25T14:15:00Z web 2>/dev/null | \
  grep -i "exception\|error.*bot\|StandardError"

REMOTE_SCRIPT

echo ""
echo "======================================================================="
