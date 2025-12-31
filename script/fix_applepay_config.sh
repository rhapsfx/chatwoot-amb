#!/bin/bash
# Quick fix for Apple Pay configuration - runs the configure script manually

echo "======================================================================="
echo "🔧 MANUAL APPLE PAY CONFIGURATION (INBOX 11)"
echo "======================================================================="
echo ""

echo "Copying configuration script to production..."
scp -q script/configure_apple_pay_inbox.rb root@msp.rhaps.net:/opt/chatwoot/script/

echo "Running configuration on production server..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
set -e
cd /opt/chatwoot

WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)

if [ -z "$WEB_CONTAINER" ]; then
    echo "❌ Web container not running"
    exit 1
fi

echo "✅ Web container found: $WEB_CONTAINER"
echo ""

# Copy script and certs to container
echo "→ Copying files to container..."
docker cp script/configure_apple_pay_inbox.rb $WEB_CONTAINER:/app/script/
docker cp certs/apple_pay/apple_pay_cert.pem $WEB_CONTAINER:/app/certs/apple_pay/
docker cp certs/apple_pay/apple_pay_private.key $WEB_CONTAINER:/app/certs/apple_pay/

# Run configuration with RAILS_ENV as environment variable (not argument!)
echo "→ Running configuration script..."
echo ""
docker exec -e RAILS_ENV=production $WEB_CONTAINER bundle exec rails runner \
  script/configure_apple_pay_inbox.rb \
  11 \
  certs/apple_pay/apple_pay_cert.pem \
  certs/apple_pay/apple_pay_private.key \
  MS58PRCFSS.com.apple.apple-pay-matthieu \
  msp.rhaps.net

echo ""
echo "✅ Configuration complete"
REMOTE_SCRIPT

echo ""
echo "======================================================================="
echo "To test Apple Pay:"
echo "  Send 'apple pay' message to the bot in inbox 11"
echo ""
echo "To check configuration:"
echo "  ./script/check_applepay_issue.sh"
echo ""
