#!/bin/bash
# Cleanup deprecated deployment scripts
# This removes 28 obsolete scripts that were replaced by the final deployment workflow
# Usage: ./script/cleanup-deployment-scripts.sh

set -e

cd "$(dirname "$0")"

echo "======================================================================="
echo "🧹 DEPLOYMENT SCRIPTS CLEANUP"
echo "======================================================================="
echo ""
echo "This will delete 28 deprecated deployment scripts that have been"
echo "replaced by the final deployment workflow:"
echo ""
echo "  KEEP: quick_rebuild.sh (Full Docker rebuild)"
echo "  KEEP: deploy-backend-enhanced.sh (Hot-patch backend)"
echo "  KEEP: deploy-backend-changes-safe.sh (Comprehensive backend)"
echo "  KEEP: deploy-apple-pay-certs.sh (Apple Pay certs)"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

echo ""
echo "Deleting build experiments..."
rm -fv build_low_memory.sh build_on_production.sh build_and_deploy_from_mac.sh
rm -fv sync-and-rebuild.sh rebuild_and_deploy_image.sh

echo ""
echo "Deleting force rebuild variations..."
rm -fv force-rebuild-on-server.sh force-rebuild-on-server-v2.sh

echo ""
echo "Deleting local build experiments..."
rm -fv deploy-local-build.sh deploy-existing-image.sh deploy-force-reload.sh
rm -fv force-reload-image.sh deploy-with-dns-fix.sh
rm -fv deploy-container-with-dns.sh deploy-container-simple.sh

echo ""
echo "Deleting container management utilities..."
rm -fv restart_production.sh restart_containers_for_code.sh
rm -fv reload_containers_with_env.sh reload_with_env.sh clear-cache-restart.sh

echo ""
echo "Deleting asset copy experiments..."
rm -fv copy-vite-assets.sh copy-vite-assets-v2.sh copy-vite-assets-v3.sh

echo ""
echo "Deleting asset-only deployment..."
rm -fv deploy-assets-only.sh deploy-frontend-with-rebuild.sh

echo ""
echo "Deleting inspection utilities..."
rm -fv quick_check_bins.sh

echo ""
echo "Deleting server-side scripts (were meant to run ON server)..."
rm -fv tag-image-on-server.sh

echo ""
echo "======================================================================="
echo "✅ CLEANUP COMPLETE!"
echo "======================================================================="
echo ""
echo "Deleted 28 deprecated scripts"
echo ""
echo "Remaining deployment scripts:"
ls -1 *.sh 2>/dev/null | grep -E "^(quick_rebuild|deploy-backend|deploy-apple)" | sed 's/^/  ✅ /'
echo ""
echo "Next steps:"
echo "  1. Review remaining scripts above"
echo "  2. Commit changes: git add -A && git commit -m 'chore: remove 28 deprecated deployment scripts'"
echo ""
