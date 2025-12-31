#!/bin/bash
# Check production server git status and deployment

echo "======================================================================="
echo "🔍 CHECKING PRODUCTION SERVER DEPLOYMENT STATUS"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "1. Current git branch:"
git branch --show-current
echo ""

echo "2. Latest commit on production:"
git log -1 --oneline
echo ""

echo "3. Check if AppleMapsService file exists:"
if [ -f "app/services/apple_messages_for_business/apple_maps_service.rb" ]; then
    echo "✅ File exists"
    echo "   File size: $(ls -lh app/services/apple_messages_for_business/apple_maps_service.rb | awk '{print $5}')"
    echo "   Modified: $(ls -l app/services/apple_messages_for_business/apple_maps_service.rb | awk '{print $6, $7, $8}')"
else
    echo "❌ File does NOT exist"
    echo ""
    echo "   Files in app/services/apple_messages_for_business/:"
    ls -1 app/services/apple_messages_for_business/ | head -10
fi
echo ""

echo "4. Check git status for unstaged changes:"
git status --short app/services/apple_messages_for_business/
echo ""

echo "5. Compare with remote:"
git fetch origin --quiet
CURRENT_BRANCH=$(git branch --show-current)
echo "   Behind origin/$CURRENT_BRANCH by:"
git rev-list HEAD..origin/$CURRENT_BRANCH --count
echo "   commits"

REMOTE_SCRIPT

echo ""
echo "======================================================================="
