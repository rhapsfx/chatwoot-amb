#!/bin/bash
# Helper script to show how to update .env file with Apple Maps private key

echo "📝 How to Update Your .env File"
echo ""
echo "Add these lines to your .env file:"
echo ""
echo "# Apple Maps Server API Credentials"
echo 'APPLE_MAPS_TEAM_ID=MS58PRCFSS'
echo 'APPLE_MAPS_KEY_ID=T7U5CM995R'
echo 'APPLE_MAPS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQglEFy5i6RGWF3Mfat
/XtPBRUWZA5iPGLo0T9GIbF1/+qgCgYIKoZIzj0DAQehRANCAASkMzSJNdfwG/Kk
do6emVSQfSDVrl3nJ+8dTzUvAxWIOF1xqjnFizWrvIyYtpgTYOrPTlS/sXKYBxv6
r3ZfI2HW
-----END PRIVATE KEY-----"'
echo ""
echo "⚠️  IMPORTANT:"
echo "   - Keep the quotes around the PRIVATE_KEY value"
echo "   - Keep the newlines (\\n) in the multi-line string"
echo "   - Save the file and restart your Rails server"
echo ""
echo "After updating, restart your server:"
echo "   1. Stop the current server (Ctrl+C or overmind stop)"
echo "   2. Restart: overmind start -f Procfile.dev"
echo "   3. Test: rails runner script/test_apple_maps_integration.rb"
echo ""
