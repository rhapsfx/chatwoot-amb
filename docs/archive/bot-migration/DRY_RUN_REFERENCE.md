# Dry-Run Mode Reference

## Example Output: Import with Dry-Run

### Command
```bash
rails runner script/import_migrated_bots.rb --account-id 1 --dry-run
```

### Expected Output

```
🚀 Importing Migrated Bot Data to Chatwoot
============================================================
⚠️  DRY-RUN MODE - No changes will be made
============================================================
Account ID: 1
✓ Found account: My Chatwoot Account (ID: 1)

🏢 Importing: ACOUSTIC_HOUSE
------------------------------------------------------------
  ➕ Would create new bot: Acoustic House
     Description: Migrated from Acoustic House Flask bot
     Bot type: webhook
     Business type: acoustic_house
     Migrated at: 2025-01-05T12:34:56Z

  📄 Would import 25 templates:
     • lp_summary_0319_apple_list_picker
       - Request ID: lp_summary_0319
       - Content Type: apple_list_picker
       - Language: en
     • lp_guitar_0319_apple_list_picker
       - Request ID: lp_guitar_0319
       - Content Type: apple_list_picker
       - Language: en
     • time_0319_apple_time_picker
       - Request ID: time_0319
       - Content Type: apple_time_picker
       - Language: en
     • applepay_1018_apple_pay
       - Request ID: applepay_1018
       - Content Type: apple_pay
       - Language: en
     • form_help_me_decide_apple_form
       - Request ID: form_help_me_decide
       - Content Type: apple_form
       - Language: en
     ... and 20 more templates

  🖼️  Would import 42 images:
     • summary_listpicker_0.png (45.23 KB)
     • summary_listpicker_1.png (38.91 KB)
     • summary_listpicker_2.png (42.15 KB)
     • summary_listpicker_3.png (39.87 KB)
     • summary_listpicker_4.png (41.02 KB)
     ... and 37 more images

🏢 Importing: ACOUSTIC_SHACK
------------------------------------------------------------
  ➕ Would create new bot: Acoustic Shack
     Description: Migrated from Acoustic Shack Flask bot
     Bot type: webhook
     Business type: acoustic_shack
     Migrated at: 2025-01-05T12:34:56Z

  📄 Would import 15 templates:
     • form_bia_ah_apple_form
       - Request ID: form_bia_ah
       - Content Type: apple_form
       - Language: en
     • lp_shack_menu_apple_list_picker
       - Request ID: lp_shack_menu
       - Content Type: apple_list_picker
       - Language: en
     ... and 13 more templates

  🖼️  Would import 18 images:
     • bia_form_image_0.png (32.45 KB)
     • shack_menu_0.png (28.91 KB)
     ... and 16 more images

🏢 Importing: TELCO
------------------------------------------------------------
  ➕ Would create new bot: Telco
     Description: Migrated from Telco Flask bot
     Bot type: webhook
     Business type: telco
     Migrated at: 2025-01-05T12:34:56Z

  📄 Would import 20 templates:
     • lp_phone_selection_apple_list_picker
       - Request ID: lp_phone_selection
       - Content Type: apple_list_picker
       - Language: en
     • lp_plan_comparison_apple_list_picker
       - Request ID: lp_plan_comparison
       - Content Type: apple_list_picker
       - Language: en
     ... and 18 more templates

  🖼️  Would import 25 images:
     • phone_iphone_15.png (52.34 KB)
     • phone_iphone_15_pro.png (55.12 KB)
     ... and 23 more images

============================================================
📊 Dry-Run Preview Summary
============================================================
Would create bots: 3
Would create templates: 60
Would upload images: 85

Total changes that would be made: 148

ℹ️  This was a preview only - no changes were made

📋 To execute the import:
  rails runner script/import_migrated_bots.rb --account-id 1
```

## Example Output: Dry-Run with Existing Bot

If bot already exists:

```
🏢 Importing: ACOUSTIC_HOUSE
------------------------------------------------------------
  📋 Would update existing bot: Acoustic House (ID: 42)
     Description: Migrated from Acoustic House Flask bot
     Bot type: webhook
     Business type: acoustic_house
     Migrated at: 2025-01-05T12:34:56Z

  📄 Would import 25 templates:
     ...
```

## Example Output: Dry-Run with Missing Account

```bash
rails runner script/import_migrated_bots.rb --account-id 999 --dry-run
```

Output:
```
🚀 Importing Migrated Bot Data to Chatwoot
============================================================
⚠️  DRY-RUN MODE - No changes will be made
============================================================
Account ID: 999
✗ Account ID 999 not found
```

## Usage Examples

### Preview all businesses
```bash
rails runner script/import_migrated_bots.rb --account-id 1 --dry-run
```

### Preview specific business only
```bash
rails runner script/import_migrated_bots.rb --account-id 1 --business acoustic_house --dry-run
```

### Preview with interactive account selection
```bash
rails runner script/import_migrated_bots.rb --dry-run
```
Output:
```
🚀 Importing Migrated Bot Data to Chatwoot
============================================================
⚠️  DRY-RUN MODE - No changes will be made
============================================================
Available accounts:
  1: Production Account
  2: Staging Account
  3: Development Account

Enter account ID: 1
✓ Would use account: Production Account (ID: 1)
...
```

## Comparing Dry-Run vs Actual Import

### Dry-Run Mode
- ✅ Reads migration files
- ✅ Validates JSON structure
- ✅ Checks if accounts exist
- ✅ Checks if bots already exist
- ✅ Calculates statistics
- ✅ Shows file sizes for images
- ❌ **Does NOT create database records**
- ❌ **Does NOT upload images**
- ❌ **Does NOT modify bot_config**

### Actual Import Mode
- ✅ Reads migration files
- ✅ Validates JSON structure
- ✅ **Creates AgentBot records**
- ✅ **Stores templates in bot_config**
- ✅ **Uploads images to ActiveStorage**
- ✅ Shows progress and IDs

## Quick Reference: All Flags

```bash
# Dry-run all businesses
rails runner script/import_migrated_bots.rb --dry-run --account-id 1

# Dry-run specific business
rails runner script/import_migrated_bots.rb --dry-run --account-id 1 --business acoustic_house

# Actual import all businesses
rails runner script/import_migrated_bots.rb --account-id 1

# Actual import specific business
rails runner script/import_migrated_bots.rb --account-id 1 --business telco
```

## Recommended Workflow

1. **First: Always dry-run**
   ```bash
   rails runner script/import_migrated_bots.rb --account-id 1 --dry-run
   ```

2. **Review the output**
   - Check bot counts
   - Verify template counts
   - Check image file sizes
   - Look for any errors

3. **If satisfied, run actual import**
   ```bash
   rails runner script/import_migrated_bots.rb --account-id 1
   ```

4. **Verify in Rails console**
   ```ruby
   AgentBot.where(account_id: 1).pluck(:name, :id)
   # => [["Acoustic House", 1], ["Acoustic Shack", 2], ["Telco", 3]]

   bot = AgentBot.find(1)
   bot.bot_config['templates'].size
   # => 25
   ```

## Troubleshooting Dry-Run

**Issue**: "No migration data found"
- **Cause**: Migration script not run yet
- **Fix**: Run `ruby script/migrate_apple_bot.rb` first

**Issue**: "Account ID not found"
- **Cause**: Invalid account ID
- **Fix**: Check `Account.pluck(:id, :name)` in Rails console

**Issue**: Template count seems low
- **Cause**: Only migrating one language
- **Fix**: This is expected - br and jp variants not yet migrated

**Issue**: Image sizes very large
- **Cause**: Base64 encoding overhead
- **Fix**: This is normal - sizes shown are actual PNG file sizes

## Next Steps After Dry-Run

If dry-run looks good:

1. **Run actual import**
2. **Assign bots to inboxes**
3. **Configure webhooks (if needed)**
4. **Test flows**

If dry-run shows issues:

1. **Review migration_data.json manually**
2. **Check for JSON syntax errors**
3. **Verify image files exist**
4. **Re-run migration script if needed**
