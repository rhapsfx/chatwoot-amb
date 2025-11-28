# Acoustic House Bot Template Auto-Detection System

## Overview

The Acoustic House Bot uses a sophisticated auto-detection system to manage template dependencies during deployment. This ensures that all required templates are synced to production without hardcoding template IDs.

## Architecture

### Self-Documenting Constant

The bot service declares its template dependencies in a constant:

```ruby
# app/services/apple_messages_for_business/acoustic_house_bot_service.rb
REQUIRED_TEMPLATES = %w[
  ah_guitar_list_picker
  ah_guitar_info_form
  ah_large_form_demo
  ah_main_menu
  ah_ar_guitar
  ah_apple_pay_request
].freeze
```

### Class Methods

Three class methods provide programmatic access to template dependencies:

```ruby
# Get template names
AppleMessagesForBusiness::AcousticHouseBotService.required_template_names
# => ["ah_guitar_list_picker", "ah_guitar_info_form", ...]

# Get template IDs for an account
AppleMessagesForBusiness::AcousticHouseBotService.required_template_ids(1)
# => [123, 124, 125, ...]

# Verify all templates exist
AppleMessagesForBusiness::AcousticHouseBotService.verify_templates_exist(1)
# => { all_present: true, found: [[123, "ah_guitar_list_picker"], ...], missing: [] }
```

## Scripts

### 1. Drift Detection (`script/detect_acoustic_house_bot_templates.rb`)

Validates that the `REQUIRED_TEMPLATES` constant matches actual template usage in the code.

**Usage:**
```bash
# Basic check
rails runner script/detect_acoustic_house_bot_templates.rb

# Verbose mode (shows line-by-line detection)
rails runner script/detect_acoustic_house_bot_templates.rb --verbose
```

**Exit Codes:**
- `0` - No drift detected (constant matches code)
- `1` - Drift detected (constant needs updating)
- `2` - Script error

**Output Example:**
```
🔍 Acoustic House Bot Template Drift Detection
======================================================================

📋 Declared in REQUIRED_TEMPLATES constant: 6
   - ah_apple_pay_request
   - ah_ar_guitar
   - ah_guitar_info_form
   - ah_guitar_list_picker
   - ah_large_form_demo
   - ah_main_menu

🔎 Detected from code analysis: 6
   - ah_apple_pay_request
   - ah_ar_guitar
   - ah_guitar_info_form
   - ah_guitar_list_picker
   - ah_large_form_demo
   - ah_main_menu

✅ No drift detected - constant matches code usage
```

### 2. Template Export (`script/export_acoustic_house_bot_templates.rb`)

Exports all required templates, content blocks, shared images, and picker images for deployment.

**Usage:**
```bash
# Export for account 1 (default output: tmp/acoustic_house_bot_templates.json)
rails runner script/export_acoustic_house_bot_templates.rb

# Specify account and output file
rails runner script/export_acoustic_house_bot_templates.rb 1 /tmp/bot_templates.json
```

**Export Includes:**
- MessageTemplate records (with metadata or content blocks)
- ContentBlock records (if using content blocks storage)
- SharedAppleImage records (referenced by templates)
- AppleListPickerImage records (inbox-specific overrides)
- AR .usdz file attachments (base64-encoded)

**Output Example:**
```json
{
  "metadata": {
    "account_id": 1,
    "exported_at": "2025-01-19T10:30:00Z",
    "exported_by": "AcousticHouseBotTemplateExporter",
    "template_names": ["ah_guitar_list_picker", ...],
    "version": "1.0"
  },
  "templates": [...],
  "content_blocks": [...],
  "shared_images": [...],
  "picker_images": [...]
}
```

### 3. Deployment Integration (`script/deploy-backend-changes-safe.sh`)

The deployment script automatically:
1. Runs drift detection as pre-deployment check
2. Exports templates using auto-detected IDs
3. Copies export file to production server
4. Imports templates into production database
5. Verifies template sync success

**Step 1.8 - Template Sync Flow:**
```bash
# Local (development machine)
→ Detect drift in REQUIRED_TEMPLATES
→ Export templates with auto-detected IDs
→ Copy export file to production server

# Remote (production server)
→ Import templates into production database
→ Import content blocks (if present)
→ Import shared images with attachments
→ Clean up temporary files
```

## Usage Scenarios

### Adding a New Template

1. **Create the template** in your local Chatwoot instance
2. **Add to bot service:**
   ```ruby
   # app/services/apple_messages_for_business/acoustic_house_bot_service.rb
   REQUIRED_TEMPLATES = %w[
     ah_guitar_list_picker
     ah_guitar_info_form
     ah_large_form_demo
     ah_main_menu
     ah_ar_guitar
     ah_apple_pay_request
     ah_new_template  # ← Add new template name
   ].freeze
   ```
3. **Use template in bot code:**
   ```ruby
   def send_new_feature
     template = MessageTemplate.find_by(
       account_id: @conversation.account_id,
       name: 'ah_new_template'
     )
     # ... use template
   end
   ```
4. **Run drift detection:**
   ```bash
   rails runner script/detect_acoustic_house_bot_templates.rb
   # Should show: ✅ No drift detected
   ```
5. **Deploy:** The deployment script will automatically include the new template

### Removing an Unused Template

1. **Remove from bot code** (delete the method that uses it)
2. **Run drift detection:**
   ```bash
   rails runner script/detect_acoustic_house_bot_templates.rb
   # Will show: ⚠️ Templates in REQUIRED_TEMPLATES but NOT used in code
   ```
3. **Update constant:**
   ```ruby
   # Remove unused template name from REQUIRED_TEMPLATES
   ```
4. **Verify:**
   ```bash
   rails runner script/detect_acoustic_house_bot_templates.rb
   # Should show: ✅ No drift detected
   ```
5. **Deploy:** Template will no longer be synced

### Manual Template Verification

Check templates on production server:

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

## Maintenance

### Pre-Deployment Checklist

1. ✅ Run drift detection locally
2. ✅ Verify all templates exist in local database
3. ✅ Test bot functionality with all templates
4. ✅ Review export output (check for missing images)
5. ✅ Run deployment script
6. ✅ Verify templates on production server

### Troubleshooting

**Problem:** Drift detected - missing from constant
- **Cause:** New template used in code but not added to REQUIRED_TEMPLATES
- **Fix:** Add template name to REQUIRED_TEMPLATES constant

**Problem:** Drift detected - extra in constant
- **Cause:** Template removed from code but still in REQUIRED_TEMPLATES
- **Fix:** Remove template name from REQUIRED_TEMPLATES constant

**Problem:** Export shows missing templates
- **Cause:** Templates not created in local database yet
- **Fix:** Create templates via Chatwoot UI or seed script

**Problem:** Import fails on production
- **Cause:** Database constraints, missing account, or container not running
- **Fix:** Check logs, verify account exists, ensure containers are running

## Benefits

1. **Self-Documenting**: REQUIRED_TEMPLATES constant clearly shows dependencies
2. **Drift Prevention**: Automated validation ensures constant stays in sync with code
3. **No Hardcoding**: Template IDs queried dynamically, not hardcoded
4. **Automatic Sync**: Deployment script handles export/import automatically
5. **Safe Deployment**: Pre-deployment checks catch issues before production
6. **Maintainable**: Adding/removing templates requires minimal code changes

## Related Files

- **Bot Service**: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`
- **Drift Detection**: `script/detect_acoustic_house_bot_templates.rb`
- **Export Script**: `script/export_acoustic_house_bot_templates.rb`
- **Deployment**: `script/deploy-backend-changes-safe.sh` (Step 1.8)
- **Documentation**: `docs/apple-messages/ACOUSTIC_HOUSE_BOT_TEMPLATE_SYNC.md` (this file)
