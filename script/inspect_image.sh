#!/bin/bash
# Inspect the new Docker image to see what's wrong

echo "======================================================================="
echo "🔍 INSPECTING NEW DOCKER IMAGE"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "1. Check if Dockerfile.production.lightweight exists:"
cat Dockerfile.production.lightweight | head -30
echo ""

echo "2. Inspect image structure:"
docker run --rm chatwoot:production ls -la /app/ | head -20
echo ""

echo "3. Check if bundler is installed:"
docker run --rm chatwoot:production which bundle
echo ""

echo "4. Check /usr/local/bundle:"
docker run --rm chatwoot:production ls -la /usr/local/bundle/ 2>&1 | head -10
echo ""

echo "5. Check Ruby and Bundler version:"
docker run --rm chatwoot:production ruby --version
docker run --rm chatwoot:production gem list bundler
echo ""

echo "6. Check the last build log for gem installation:"
grep -A 20 "bundle install" /tmp/fresh_build.log | tail -30

REMOTE_SCRIPT

echo ""
echo "======================================================================="
