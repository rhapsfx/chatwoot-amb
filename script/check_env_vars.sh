#!/bin/bash
# Check if environment variables are loaded in container

echo "======================================================================="
echo "🔍 CHECKING ENVIRONMENT VARIABLES IN CONTAINER"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "1. Check if .env file exists on host:"
ls -la .env
echo ""

echo "2. Check APPLE_MAPS variables in host .env:"
grep APPLE_MAPS .env | head -3
echo ""

echo "3. Check if docker-compose.production.yml loads .env:"
grep -A 5 "env_file:\|environment:" docker-compose.production.yml | head -20
echo ""

echo "4. Check APPLE_MAPS variables inside web container:"
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
echo "Checking environment in container $WEB_CONTAINER:"
docker exec $WEB_CONTAINER bash -c 'env | grep APPLE_MAPS || echo "(No APPLE_MAPS variables found)"'
echo ""

echo "5. Check if container can see .env file:"
docker exec $WEB_CONTAINER bash -c 'ls -la .env 2>/dev/null || echo "(.env not found in container)"'

REMOTE_SCRIPT

echo ""
echo "======================================================================="
