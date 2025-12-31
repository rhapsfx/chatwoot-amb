# Template Auto-Detection System - Implementation Complete

## Status: ✅ READY FOR DEPLOYMENT

All bot template lookups have been converted from hardcoded IDs to name-based lookups, enabling portable template synchronization across environments.

**Recent Fixes**:
- Export script updated to handle ActiveStorage attachments correctly (removed invalid `.includes(:attachments)`)
- Fixed constant resolution in export script (all model references now use global scope `::` operator)
- Corrected model name from `ContentBlock` to `TemplateContentBlock`
- Fixed content block query to use `message_template_id` instead of polymorphic association fields
- Updated import logic to match actual `TemplateContentBlock` schema

## Changes Summary

### 1. Bot Service Updates

**File**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

**Added REQUIRED_TEMPLATES Constant** (lines 6-16):
```ruby
REQUIRED_TEMPLATES = %w[
  ah_guitar_list_picker
  ah_guitar_info_form
  ah_large_form_demo
  ah_main_menu
  ah_ar_guitar
  ah_summary
].freeze
```

**Added Class Methods** (lines 18-49):
- `self.required_template_names` - Returns array of template names
- `self.required_template_ids(account_id)` - Returns array of template IDs for an account
- `self.verify_templates_exist(account_id)` - Verifies all templates exist

**Converted 6 Template Lookups** (from ID-based to name-based):
1. ✅ `send_guitar_list_picker` - 371 → 'ah_guitar_list_picker'
2. ✅ `send_guitar_info_form` - 356 → 'ah_guitar_info_form'
3. ✅ `send_large_content_form` - 343 → 'ah_large_form_demo'
4. ✅ `send_ar_file` - 344 → 'ah_ar_guitar'
5. ✅ `send_menu_list_picker` - 366 → 'ah_main_menu'
6. ✅ `send_summary_list_picker` - 355 → 'ah_summary'

### 2. Automated Rename Script

**File**: `script/rename_acoustic_house_bot_templates.rb`

**Template ID Mappings**:
```ruby
TEMPLATE_MAPPINGS = {
  371 => 'ah_guitar_list_picker',    # Guitar list picker
  356 => 'ah_guitar_info_form',      # Guitar info form
  343 => 'ah_large_form_demo',       # Large content form
  344 => 'ah_ar_guitar',             # AR guitar file
  366 => 'ah_main_menu',             # Main menu
  355 => 'ah_summary'                # Summary list picker
}.freeze
```

**Features**:
- Dry-run mode (default) - Preview changes before executing
- Execute mode (`--execute`) - Actually perform renames
- Account-scoped (`--account-id=N`) - Target specific account
- Conflict detection - Warns if target name already exists
- Detailed logging - Shows current name → new name for each template
- Exit codes:
  - `0` - Success (all renames complete or dry-run)
  - `1` - Error (templates not found or conflicts)

### 3. Deployment Integration

**File**: `script/deploy-backend-changes-safe.sh`

**Added Step 1.8** - Acoustic House Bot Template Sync (lines 173-315):
1. Run drift detection locally (pre-deployment check)
2. Export templates with auto-detected IDs
3. Copy export file to production server
4. Import templates into production database
5. Import content blocks (if present)
6. Import shared images with attachments
7. Clean up temporary files

### 4. Supporting Scripts

**Drift Detection**: `script/detect_acoustic_house_bot_templates.rb`
- Validates REQUIRED_TEMPLATES matches actual code usage
- Prevents deployment with outdated constant
- Exit code 0 = no drift, 1 = drift detected

**Template Export**: `script/export_acoustic_house_bot_templates.rb`
- Exports templates using auto-detected IDs (not hardcoded)
- Includes: templates, content_blocks, shared_images, picker_images
- Base64-encodes attachments for transport
- JSON format for easy import

### 5. Documentation

**Complete Guide**: `docs/apple-messages/ACOUSTIC_HOUSE_BOT_TEMPLATE_SYNC.md`
- Architecture overview
- Usage scenarios (adding/removing templates)
- Troubleshooting guide
- Pre-deployment checklist
- Manual verification commands

## Verification

### Drift Detection Results

```bash
$ rails runner script/detect_acoustic_house_bot_templates.rb

🔍 Acoustic House Bot Template Drift Detection
======================================================================

✅ No drift detected - constant matches code usage
```

**Result**: ✅ PASSED - All 6 templates declared and used correctly

### Hardcoded ID Check

```bash
$ grep -n "id: [0-9]" app/services/apple_messages_for_business/acoustic_house_bot_service.rb | grep -i template

# No output - no hardcoded IDs remain
```

**Result**: ✅ PASSED - All template lookups use name-based queries

## Next Steps for User

### Step 1: Rename Templates Locally (REQUIRED)

**Dry-run first** (recommended):
```bash
rails runner script/rename_acoustic_house_bot_templates.rb
```

Expected output:
```
🔄 Acoustic House Bot Template Rename
======================================================================
Account ID: 1
Mode: DRY RUN

📋 Template ID 371
    Current name: 'Guitar List Picker'
    New name:     'ah_guitar_list_picker'
    ℹ️  Would rename (dry-run mode)

[... 5 more templates ...]

======================================================================
Summary:
  Templates to rename: 6
  Renamed:            6
  Skipped:            0
  Errors:             0

ℹ️  This was a dry-run. Add --execute to perform the renames.
   Example: rails runner script/rename_acoustic_house_bot_templates.rb --execute
```

**Execute rename** (if dry-run looks good):
```bash
rails runner script/rename_acoustic_house_bot_templates.rb --execute
```

Expected output:
```
🔄 Acoustic House Bot Template Rename
======================================================================
Account ID: 1
Mode: EXECUTE

🔄 Template ID 371
    Current name: 'Guitar List Picker'
    New name:     'ah_guitar_list_picker'
    ✅ Renamed successfully

[... 5 more templates ...]

======================================================================
Summary:
  Templates to rename: 6
  Renamed:            6
  Skipped:            0
  Errors:             0

✅ Rename complete - all templates updated
```

### Step 2: Test Bot Locally (REQUIRED)

1. Start development server:
   ```bash
   ./script/dev-server.sh start
   ```

2. Trigger bot in Apple Messages conversation

3. Verify all 6 templates work:
   - ✅ Guitar list picker appears
   - ✅ Guitar info form appears
   - ✅ Main menu appears
   - ✅ AR guitar file sends
   - ✅ Large form demo works
   - ✅ Summary list picker appears

4. Check logs for template loading:
   ```bash
   tail -f log/development.log | grep "Bot"
   ```

Expected log entries:
```
[Bot] Sending Guitar List Picker (Name: ah_guitar_list_picker, ID: 371)
[Bot] Sending Guitar Info Form (Name: ah_guitar_info_form, ID: 356)
[Bot] 🎸 Sending AR content (Name: ah_ar_guitar, ID: 344)
[Bot] Sending Menu List Picker (Name: ah_main_menu, ID: 366)
[Bot] 📋 Sending Large Content Form (Name: ah_large_form_demo, ID: 343)
[Bot] Sending Summary List Picker (Name: ah_summary, ID: 355)
```

### Step 3: Deploy to Production (SAFE)

Once local testing passes, deploy:

```bash
./script/deploy-backend-changes-safe.sh
```

**Step 1.8 will automatically**:
1. Run drift detection (fails deploy if drift found)
2. Export templates from local database
3. Copy to production server
4. Import into production database
5. Verify template sync

**Monitor deployment output**:
```
Step 1.8: Syncing Acoustic House Bot templates to production...
  → Detecting required templates from bot service
  → Running drift detection (pre-deployment check)...
  ✅ No drift detected - REQUIRED_TEMPLATES is up-to-date
  → Exporting templates to: /tmp/acoustic_house_bot_templates_20250119_103045.json
  → Copying template export to production server...
  → Importing templates on production server...
  📦 Importing Acoustic House Bot Templates
  ======================================================================
  📋 Importing 6 templates...
     ✓ ah_guitar_list_picker
     ✓ ah_guitar_info_form
     ✓ ah_large_form_demo
     ✓ ah_main_menu
     ✓ ah_ar_guitar
     ✓ ah_summary
  🖼️  Importing 15 shared images...
     ✓ messages_png
     ✓ menu_icon
     [...]
  ✅ Template import complete
  ✅ Template synchronization complete
```

### Step 4: Verify Production

After deployment, verify templates on production:

```bash
ssh root@msp.rhaps.net "docker exec chatwoot-web bundle exec rails runner \
  'result = AppleMessagesForBusiness::AcousticHouseBotService.verify_templates_exist(1); \
   puts \"All Present: #{result[:all_present]}\"; \
   puts \"Found: #{result[:found].size} templates\"; \
   puts \"Missing: #{result[:missing].join(\", \")}\" if result[:missing].any?' \
  RAILS_ENV=production"
```

Expected output:
```
All Present: true
Found: 6 templates
```

## Troubleshooting

### Error: Template not found during rename

**Problem**: Template ID doesn't exist in database

**Solution**:
- Check if template exists: `rails runner "puts MessageTemplate.find_by(id: XXX).inspect"`
- Create template in Chatwoot UI if missing
- Update TEMPLATE_MAPPINGS if ID is wrong

### Error: Name conflict during rename

**Problem**: Target name already used by another template

**Solution**:
- Check existing template: `rails runner "puts MessageTemplate.find_by(name: 'ah_xxx').inspect"`
- Manually rename conflicting template first
- Or update TEMPLATE_MAPPINGS to use different name

### Error: Drift detected during deployment

**Problem**: REQUIRED_TEMPLATES constant doesn't match actual code usage

**Solution**:
- Run: `rails runner script/detect_acoustic_house_bot_templates.rb --verbose`
- Add missing templates to REQUIRED_TEMPLATES
- Remove unused templates from REQUIRED_TEMPLATES
- Commit changes and redeploy

### Error: Bot can't find template after deployment

**Problem**: Template sync failed or template wasn't exported

**Solution**:
- Check production logs: `docker compose -f docker-compose.production.yml logs web | grep Template`
- Verify template exists: See "Verify Production" command above
- Re-run export and import manually if needed

## Benefits

1. **No Hardcoded IDs**: Templates referenced by name, not ID
2. **Portable Sync**: Same templates work in dev and production
3. **Self-Documenting**: REQUIRED_TEMPLATES clearly shows dependencies
4. **Drift Prevention**: Automated validation ensures constant stays in sync
5. **Safe Deployment**: Pre-deployment checks catch issues early
6. **Maintainable**: Adding/removing templates requires minimal code changes

## Related Files

- Bot Service: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`
- Rename Script: `script/rename_acoustic_house_bot_templates.rb`
- Drift Detection: `script/detect_acoustic_house_bot_templates.rb`
- Export Script: `script/export_acoustic_house_bot_templates.rb`
- Deployment: `script/deploy-backend-changes-safe.sh` (Step 1.8)
- Documentation: `docs/apple-messages/ACOUSTIC_HOUSE_BOT_TEMPLATE_SYNC.md`
- This File: `docs/apple-messages/TEMPLATE_AUTO_DETECTION_COMPLETE.md`
