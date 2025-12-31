#!/bin/bash
# Fix docker-compose to load .env file

echo "======================================================================="
echo "🔧 FIXING DOCKER-COMPOSE TO LOAD .ENV FILE"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "Creating backup of docker-compose.production.yml..."
cp docker-compose.production.yml docker-compose.production.yml.backup.$(date +%Y%m%d_%H%M%S)
echo "✅ Backup created"
echo ""

echo "Checking current configuration..."
if grep -q "env_file:" docker-compose.production.yml; then
    echo "⚠️  env_file already present in docker-compose.production.yml"
else
    echo "📝 env_file NOT found - needs to be added"
fi
echo ""

echo "Adding env_file to web and worker services..."

# Use Python to properly edit YAML (safer than sed)
python3 << 'PYTHON'
import yaml
import sys

try:
    # Read docker-compose file
    with open('docker-compose.production.yml', 'r') as f:
        compose = yaml.safe_load(f)

    # Add env_file to web service
    if 'services' in compose and 'web' in compose['services']:
        if 'env_file' not in compose['services']['web']:
            compose['services']['web']['env_file'] = ['.env']
            print("✅ Added env_file to web service")
        else:
            print("✓ web service already has env_file")

    # Add env_file to worker service
    if 'services' in compose and 'worker' in compose['services']:
        if 'env_file' not in compose['services']['worker']:
            compose['services']['worker']['env_file'] = ['.env']
            print("✅ Added env_file to worker service")
        else:
            print("✓ worker service already has env_file")

    # Write back
    with open('docker-compose.production.yml', 'w') as f:
        yaml.dump(compose, f, default_flow_style=False, sort_keys=False)

    print("")
    print("✅ docker-compose.production.yml updated successfully")
    sys.exit(0)

except Exception as e:
    print(f"❌ Error: {e}")
    print("")
    print("Falling back to manual edit...")
    sys.exit(1)

PYTHON

if [ $? -ne 0 ]; then
    echo "Python edit failed, using sed fallback..."

    # Add env_file to web service (after 'web:' line)
    sed -i '/^  web:/a\    env_file:\n      - .env' docker-compose.production.yml

    # Add env_file to worker service (after 'worker:' line)
    sed -i '/^  worker:/a\    env_file:\n      - .env' docker-compose.production.yml

    echo "✅ docker-compose.production.yml updated via sed"
fi

echo ""
echo "Verifying changes..."
grep -A 2 "env_file:" docker-compose.production.yml || echo "⚠️  Could not find env_file in updated file"

echo ""
echo "Restarting containers to load new environment variables..."
docker compose -f docker-compose.production.yml restart web worker

echo ""
echo "Waiting for services to start..."
sleep 10

echo ""
echo "Verifying APPLE_MAPS variables are now loaded..."
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker exec $WEB_CONTAINER bash -c 'env | grep APPLE_MAPS | head -3'

REMOTE_SCRIPT

echo ""
echo "======================================================================="
echo "✅ CONFIGURATION UPDATED AND CONTAINERS RESTARTED"
echo "======================================================================="
echo ""
echo "Test Apple Maps now:"
echo "  ./script/test_apple_maps_service.sh"
echo ""
