# Deployment Script Fix - Template Import Issue Resolved

## Problem Summary

The deployment script `script/deploy-backend-changes-safe.sh` was failing to import bot templates to production, even though it reported success. The issue was caused by a **nested heredoc** structure that swallowed all output from the import process.

### Root Cause

**Lines 206-333** of `deploy-backend-changes-safe.sh` used a nested heredoc structure:
```bash
ssh root@msp.rhaps.net 'bash -s' << 'EOF_TEMPLATES'  # Outer heredoc
  docker exec ... rails runner - <<'RUBY'            # Inner heredoc (NESTED!)
    # Import code here
  RUBY
EOF_TEMPLATES
```

When bash processes nested heredocs, the output gets captured by the outer heredoc and never reaches the terminal. This caused:
- ✅ Script appeared to run successfully (no errors)
- ❌ No output was displayed
- ❌ Templates were never actually imported to the database

## Solution

**File-Based Import Approach**

Instead of using nested heredocs, the fix uses a standalone Ruby script:

1. **Created**: `script/production_import_templates.rb` - Standalone import script with proper error handling and output
2. **Updated**: `script/deploy-backend-changes-safe.sh` - Now copies the script file and executes it directly

### New Flow (Lines 204-238)

```bash
# Copy import script to server
scp script/production_import_templates.rb root@msp.rhaps.net:/tmp/

# SSH to server (single heredoc, no nesting)
ssh root@msp.rhaps.net 'bash -s' << 'EOF_TEMPLATES'
  # Copy script to container
  docker cp /tmp/production_import_templates.rb $WEB_CONTAINER:/tmp/

  # Execute script directly
  docker exec $WEB_CONTAINER bundle exec rails runner /tmp/production_import_templates.rb
EOF_TEMPLATES
```

**Benefits**:
- ✅ No nested heredocs = output displays correctly
- ✅ Better error handling with exit codes
- ✅ Detailed progress reporting
- ✅ Separate script can be run manually for troubleshooting

## Files Added

### 1. `script/production_import_templates.rb`

**Purpose**: Standalone template import script
**Usage**: Automatically used by deployment script, can also be run manually

**Features**:
- Imports templates with status validation
- Imports content blocks with relationship mapping
- Imports shared images with base64 decoding
- Detailed progress output
- Proper error handling and exit codes

**Manual Usage**:
```bash
# Copy to production and run
./script/run_manual_import.sh
```

### 2. `script/troubleshoot_deployment.sh`

**Purpose**: Comprehensive deployment health check
**Usage**: Diagnose deployment issues

**Checks**:
- ✅ Server connectivity
- ✅ Docker containers running
- ✅ Export file exists
- ✅ Templates in database
- ✅ Content blocks imported
- ✅ Bot service can find templates

**Usage**:
```bash
./script/troubleshoot_deployment.sh
```

**Output Example**:
```
=======================================================================
🔍 DEPLOYMENT HEALTH CHECK
=======================================================================

Check 1: Server connectivity...
  ✅ Can connect to msp.rhaps.net

Check 2: Docker containers running...
  ✅ Web container is running

Check 3: Export file exists on production...
  ✅ Export file exists at /tmp/bot_templates.json
     Account ID: 1
     Exported: 2025-11-25T11:30:00Z
     Templates: 6
     Content Blocks: 5
     Shared Images: 1

Check 4: Templates in production database...
  Templates found: 6/6
  ✅ All 6 templates exist in database
     ✓ ah_guitar_list_picker: 1 block(s)
     ✓ ah_guitar_info_form: 1 block(s)
     ✓ ah_large_form_demo: 1 block(s)
     ✓ ah_main_menu: 1 block(s)
     ✓ ah_ar_guitar: 0 block(s)
     ✓ ah_summary: 1 block(s)

Check 5: Bot service verification...
  ✅ Bot service can find all required templates
     Found: ah_guitar_list_picker, ah_guitar_info_form, ...

=======================================================================
SUMMARY
=======================================================================

If all checks passed:
  ✅ Deployment is healthy
  ✅ Bot should work correctly
```

### 3. `script/verify_templates_production.sh`

**Purpose**: Quick template status check
**Usage**: Fast verification of template deployment

**Usage**:
```bash
./script/verify_templates_production.sh
```

**Output Example**:
```
=== Quick Template Status Check ===

Templates Status:
======================================================================
Found: 6/6 templates

✅ ah_guitar_list_picker
   ID: 10, Status: active, Blocks: 1
✅ ah_guitar_info_form
   ID: 9, Status: active, Blocks: 1
✅ ah_large_form_demo
   ID: 13, Status: active, Blocks: 1
✅ ah_main_menu
   ID: 11, Status: active, Blocks: 1
⚠️  ah_ar_guitar
   ID: 8, Status: active, Blocks: 0
✅ ah_summary
   ID: 12, Status: active, Blocks: 1

======================================================================
✅ Bot service: ALL TEMPLATES ACCESSIBLE
```

## Usage Guide

### Normal Deployment

```bash
./script/deploy-backend-changes-safe.sh
```

**Expected Output**:
```
Step 1.8: Syncing Acoustic House Bot templates to production...
  → Running drift detection (pre-deployment check)...
  ✅ No drift detected - REQUIRED_TEMPLATES is up-to-date

  → Exporting templates to: /tmp/acoustic_house_bot_templates_20251125_110000.json
  ✅ Export complete

  → Copying template export to production server...
  → Copying import script to production server...
  → Importing templates on production server...

======================================================================
📦 Importing Acoustic House Bot Templates
======================================================================

Export metadata:
  Account ID: 1
  Exported at: 2025-11-25T11:00:00Z
  Templates: 6
  Content Blocks: 5
  Shared Images: 1

======================================================================
📋 Importing 6 templates...
======================================================================
   ✓ ah_ar_guitar (NEW, ID: 8)
   ✓ ah_guitar_info_form (NEW, ID: 9)
   ✓ ah_guitar_list_picker (NEW, ID: 10)
   ✓ ah_main_menu (NEW, ID: 11)
   ✓ ah_summary (NEW, ID: 12)
   ✓ ah_large_form_demo (NEW, ID: 13)

Templates: 6 imported, 0 errors

======================================================================
📦 Importing 5 content blocks...
======================================================================
   ✓ ah_guitar_info_form / form (NEW)
   ✓ ah_large_form_demo / form (NEW)
   ✓ ah_main_menu / list_picker (NEW)
   ✓ ah_summary / list_picker (NEW)
   ✓ ah_guitar_list_picker / list_picker (NEW)

Content blocks: 5 imported, 0 errors

======================================================================
🖼️  Importing 1 shared images...
======================================================================
   ✓ messages_png (NEW)

Shared images: 1 imported, 0 errors

======================================================================
✅ Import complete
======================================================================

✅ All data imported successfully

  ✅ Templates imported successfully
  ✅ Template synchronization complete
```

### Manual Import (If Deployment Fails)

```bash
./script/run_manual_import.sh
```

### Quick Verification

```bash
./script/verify_templates_production.sh
```

### Comprehensive Troubleshooting

```bash
./script/troubleshoot_deployment.sh
```

## Testing the Fix

To verify the fix works:

1. **Delete existing templates** on production (if needed):
```bash
ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner "MessageTemplate.where(account_id: 1, name: %w[ah_guitar_list_picker ah_guitar_info_form ah_large_form_demo ah_main_menu ah_ar_guitar ah_summary]).destroy_all" RAILS_ENV=production'
```

2. **Run deployment**:
```bash
./script/deploy-backend-changes-safe.sh
```

3. **Verify success**:
```bash
./script/verify_templates_production.sh
```

Should show:
```
✅ All 6 templates exist in database
✅ Bot service: ALL TEMPLATES ACCESSIBLE
```

## Key Improvements

1. **Output Visibility**: All import steps now display in real-time
2. **Error Detection**: Import errors immediately visible and stop deployment
3. **Debugging Tools**: Multiple scripts to diagnose issues
4. **Manual Recovery**: Can manually import if deployment fails
5. **Quick Verification**: Fast status checks without full deployment

## Related Documentation

- Export Script: `script/export_acoustic_house_bot_templates.rb`
- Drift Detection: `script/detect_acoustic_house_bot_templates.rb`
- Bot Service: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`
- Complete Guide: `docs/apple-messages/ACOUSTIC_HOUSE_BOT_TEMPLATE_SYNC.md`
- Implementation Complete: `docs/apple-messages/TEMPLATE_AUTO_DETECTION_COMPLETE.md`

## Troubleshooting Common Issues

### Issue: "Template file not found"

**Cause**: Export step failed or file was deleted
**Fix**:
```bash
# Re-run export locally
rails runner script/export_acoustic_house_bot_templates.rb 1 /tmp/bot_templates.json

# Copy to production
scp /tmp/bot_templates.json root@msp.rhaps.net:/tmp/

# Run manual import
./script/run_manual_import.sh
```

### Issue: "Web container not running"

**Cause**: Docker containers not started
**Fix**:
```bash
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml up -d'
```

### Issue: "Templates imported but not visible in UI"

**Cause**: Template status field is not 'active'
**Fix**:
```bash
# Check status
./script/verify_templates_production.sh

# Fix status if needed
ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner "MessageTemplate.where(account_id: 1, name: %w[ah_guitar_list_picker ah_guitar_info_form ah_large_form_demo ah_main_menu ah_ar_guitar ah_summary]).update_all(status: '\''active'\'')" RAILS_ENV=production'
```

### Issue: "Templates exist but content blocks missing"

**Cause**: Content block import failed
**Fix**:
```bash
# Re-run import (it will update existing templates and add missing blocks)
./script/run_manual_import.sh
```

## Summary

The deployment script has been fixed to use a file-based import approach instead of nested heredocs, ensuring:

✅ **Reliable imports** - Templates and content blocks always import correctly
✅ **Visible output** - Progress and errors display in real-time
✅ **Better debugging** - Multiple tools to diagnose and fix issues
✅ **Manual recovery** - Can import templates without full deployment
✅ **Future-proof** - Adding new templates requires minimal changes

The fix resolves the silent failure issue and provides comprehensive troubleshooting tools for future deployments.
