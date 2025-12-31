#!/bin/bash
# Check Docker build progress on production server

echo "======================================================================="
echo "📊 CHECKING DOCKER BUILD PROGRESS"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "1. Check if Docker build is running:"
if docker ps -a | grep -q "build"; then
    echo "✅ Build process detected"
else
    echo "⚠️  No active build containers visible"
fi
echo ""

echo "2. Current Docker processes:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
echo ""

echo "3. Last 30 lines of build output:"
if [ -f "/tmp/docker_build.log" ]; then
    tail -30 /tmp/docker_build.log
else
    echo "⚠️  No build log found at /tmp/docker_build.log"
fi
echo ""

echo "4. Docker system activity:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

REMOTE_SCRIPT

echo ""
echo "======================================================================="
