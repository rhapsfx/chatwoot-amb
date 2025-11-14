#!/bin/bash
# Phase 1 Migration Verification Script
# Tests file existence and code structure without database access

echo "================================================================================"
echo "Phase 1 Migration Test: apple_list_picker_images → apple_amb_images"
echo "================================================================================"
echo ""

# Check script is run from project root
if [ ! -f "Gemfile" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

echo "✅ Test Setup: Running from project root"
echo ""

# Test 1: Backend Controller Files
echo "Test 1: Backend Controller Files"
echo "--------------------------------------------------------------------------------"

OLD_CONTROLLER="app/controllers/api/v1/accounts/inboxes/apple_list_picker_images_controller.rb"
NEW_CONTROLLER="app/controllers/api/v1/accounts/inboxes/apple_amb_images_controller.rb"

if [ -f "$OLD_CONTROLLER" ]; then
    echo "✅ Old controller exists: $OLD_CONTROLLER"

    # Check for deprecation warning
    if grep -q "log_deprecation_warning" "$OLD_CONTROLLER"; then
        echo "   ✅ Deprecation warning method present"
    else
        echo "   ⚠️  Deprecation warning method not found"
    fi
else
    echo "❌ Old controller not found: $OLD_CONTROLLER"
fi

if [ -f "$NEW_CONTROLLER" ]; then
    echo "✅ New controller exists: $NEW_CONTROLLER"

    # Check class name
    if grep -q "class Api::V1::Accounts::Inboxes::AppleAmbImagesController" "$NEW_CONTROLLER"; then
        echo "   ✅ Correct class name: AppleAmbImagesController"
    else
        echo "   ❌ Incorrect class name"
    fi
else
    echo "❌ New controller not found: $NEW_CONTROLLER"
fi

echo ""

# Test 2: Routes
echo "Test 2: Routes Configuration"
echo "--------------------------------------------------------------------------------"

if grep -q "resources :apple_list_picker_images" config/routes.rb; then
    echo "✅ Old routes present in config/routes.rb"
fi

if grep -q "resources :apple_amb_images" config/routes.rb; then
    echo "✅ New routes present in config/routes.rb"
else
    echo "❌ New routes not found in config/routes.rb"
fi

# Check if both are present
if grep -q "resources :apple_list_picker_images" config/routes.rb && grep -q "resources :apple_amb_images" config/routes.rb; then
    echo "   ✅ Both route sets exist (Phase 1 non-breaking migration)"
fi

echo ""

# Test 3: Frontend API Clients
echo "Test 3: Frontend API Client Files"
echo "--------------------------------------------------------------------------------"

OLD_CLIENT="app/javascript/dashboard/api/appleListPickerImages.js"
NEW_CLIENT="app/javascript/dashboard/api/appleAmbImages.js"

if [ -f "$OLD_CLIENT" ]; then
    echo "✅ Old API client exists: $OLD_CLIENT"
else
    echo "❌ Old API client not found"
fi

if [ -f "$NEW_CLIENT" ]; then
    echo "✅ New API client exists: $NEW_CLIENT"

    # Check resource name
    if grep -q "'apple_amb_images'" "$NEW_CLIENT"; then
        echo "   ✅ Correct resource name: 'apple_amb_images'"
    else
        echo "   ❌ Resource name not correct"
    fi

    # Check class name
    if grep -q "class AppleAmbImagesAPI" "$NEW_CLIENT"; then
        echo "   ✅ Correct class name: AppleAmbImagesAPI"
    else
        echo "   ❌ Class name not correct"
    fi
else
    echo "❌ New API client not found"
fi

echo ""

# Test 3b: Simplified Frontend API Clients (for AppleMessagesComposer)
echo "Test 3b: Simplified Frontend API Client Files"
echo "--------------------------------------------------------------------------------"

OLD_MESSAGES_CLIENT="app/javascript/dashboard/api/appleMessagesImages.js"
NEW_MESSAGES_CLIENT="app/javascript/dashboard/api/appleAmbMessagesImages.js"

if [ -f "$OLD_MESSAGES_CLIENT" ]; then
    echo "✅ Old messages API client exists: $OLD_MESSAGES_CLIENT"

    # Check for deprecation warning
    if grep -q "DEPRECATED" "$OLD_MESSAGES_CLIENT"; then
        echo "   ✅ Deprecation warning present"
    else
        echo "   ⚠️  Deprecation warning not found"
    fi
else
    echo "❌ Old messages API client not found"
fi

if [ -f "$NEW_MESSAGES_CLIENT" ]; then
    echo "✅ New messages API client exists: $NEW_MESSAGES_CLIENT"

    # Check endpoint name
    if grep -q "apple_amb_images" "$NEW_MESSAGES_CLIENT"; then
        echo "   ✅ Uses new endpoint: apple_amb_images"
    else
        echo "   ❌ Endpoint not updated"
    fi

    # Check class name
    if grep -q "class AppleAmbMessagesImagesAPI" "$NEW_MESSAGES_CLIENT"; then
        echo "   ✅ Correct class name: AppleAmbMessagesImagesAPI"
    else
        echo "   ❌ Class name not correct"
    fi
else
    echo "❌ New messages API client not found"
fi

echo ""

# Test 4: Component Migration
echo "Test 4: Component Migration Status"
echo "--------------------------------------------------------------------------------"

MODAL="app/javascript/dashboard/routes/dashboard/settings/templates/components/ImageValidationModal.vue"

if [ -f "$MODAL" ]; then
    echo "✅ ImageValidationModal.vue exists"

    if grep -q "AppleAmbImagesAPI" "$MODAL"; then
        echo "   ✅ Component uses new API client (AppleAmbImagesAPI)"
    else
        echo "   ⚠️  Component not yet migrated to new API client"
    fi
else
    echo "⚠️  ImageValidationModal.vue not found (optional component)"
fi

COMPOSER="app/javascript/dashboard/components/widgets/conversation/ReplyBox/AppleMessagesComposer.vue"

if [ -f "$COMPOSER" ]; then
    echo "✅ AppleMessagesComposer.vue exists"

    if grep -q "from 'dashboard/api/appleAmbMessagesImages'" "$COMPOSER"; then
        echo "   ✅ Component uses new API client (appleAmbMessagesImages)"
    else
        echo "   ⚠️  Component not yet migrated to new API client"
    fi
else
    echo "⚠️  AppleMessagesComposer.vue not found"
fi

echo ""

# Test 5: Documentation
echo "Test 5: Documentation Updates"
echo "--------------------------------------------------------------------------------"

if [ -f "docs/apple-messages/APPLE_AMB_IMAGES_MIGRATION_PHASE_1.md" ]; then
    echo "✅ Migration guide exists: APPLE_AMB_IMAGES_MIGRATION_PHASE_1.md"
else
    echo "⚠️  Migration guide not found"
fi

if grep -q "apple_amb_images" CLAUDE.md; then
    echo "✅ CLAUDE.md updated with new endpoint name"
else
    echo "⚠️  CLAUDE.md not updated"
fi

echo ""

# Test 6: Code Structure Validation
echo "Test 6: Code Structure Validation"
echo "--------------------------------------------------------------------------------"

# Check that new controller has all necessary methods
if [ -f "$NEW_CONTROLLER" ]; then
    METHODS=("index" "create" "destroy" "copy_from" "bulk_upload")
    MISSING=()

    for method in "${METHODS[@]}"; do
        if grep -q "def $method" "$NEW_CONTROLLER"; then
            echo "   ✅ Method present: $method"
        else
            MISSING+=("$method")
        fi
    done

    if [ ${#MISSING[@]} -eq 0 ]; then
        echo "✅ All required methods present in new controller"
    else
        echo "❌ Missing methods: ${MISSING[*]}"
    fi
fi

echo ""

# Summary
echo "================================================================================"
echo "Test Summary"
echo "================================================================================"
echo ""

# Count successes
TOTAL=0
SUCCESS=0

# Backend files
if [ -f "$OLD_CONTROLLER" ] && [ -f "$NEW_CONTROLLER" ]; then
    SUCCESS=$((SUCCESS + 1))
fi
TOTAL=$((TOTAL + 1))

# Routes
if grep -q "resources :apple_amb_images" config/routes.rb; then
    SUCCESS=$((SUCCESS + 1))
fi
TOTAL=$((TOTAL + 1))

# Frontend files
if [ -f "$OLD_CLIENT" ] && [ -f "$NEW_CLIENT" ]; then
    SUCCESS=$((SUCCESS + 1))
fi
TOTAL=$((TOTAL + 1))

# Documentation
if [ -f "docs/apple-messages/APPLE_AMB_IMAGES_MIGRATION_PHASE_1.md" ]; then
    SUCCESS=$((SUCCESS + 1))
fi
TOTAL=$((TOTAL + 1))

echo "Results: $SUCCESS/$TOTAL core checks passed"
echo ""

if [ $SUCCESS -eq $TOTAL ]; then
    echo "✅ Phase 1 Migration appears successful!"
    echo ""
    echo "Next Steps:"
    echo "1. Run linters:"
    echo "   bundle exec rubocop -a"
    echo "   cd app/javascript && pnpm eslint --fix"
    echo ""
    echo "2. Test endpoints manually:"
    echo "   - Start dev server: ./dev-server.sh start"
    echo "   - Old endpoint should log deprecation warnings"
    echo "   - New endpoint should work identically"
    echo ""
    echo "3. Monitor logs:"
    echo "   tail -f log/development.log | grep DEPRECATED"
    echo ""
    exit 0
else
    echo "⚠️  Some checks failed. Review output above."
    exit 1
fi
