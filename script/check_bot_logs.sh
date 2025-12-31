#!/bin/bash
# Check Acoustic House Bot logs on production (fixed for Docker)

echo "======================================================================="
echo "🔍 ACOUSTIC HOUSE BOT - LOG ANALYSIS"
echo "======================================================================="
echo ""

echo "Fetching recent bot-related logs (last 100 lines)..."
echo ""

ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs --tail=100 web 2>/dev/null | grep -i "bot\|acoustic\|template\|ah_guitar\|ah_main\|ah_summary\|list_picker\|form" || echo "No bot-related logs found"'

echo ""
echo "======================================================================="
echo "Checking for errors (last 50 lines)..."
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs --tail=200 web 2>/dev/null | grep -i "error\|exception\|failed" | tail -20 || echo "No errors found"'

echo ""
echo "======================================================================="
echo "Recent message activity..."
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs --tail=200 web 2>/dev/null | grep "MessagesController" | tail -10'

echo ""
echo "======================================================================="
echo ""
echo "To see live logs:"
echo "  ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs web -f | grep -i bot'"
echo ""
echo "To check specific conversation messages:"
echo "  ./script/debug_bot_behavior.sh"
echo ""
