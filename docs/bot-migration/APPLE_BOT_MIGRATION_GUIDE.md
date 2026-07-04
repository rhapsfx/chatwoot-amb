# Apple Messages Bot Migration Guide

## Overview

This guide helps you migrate the old Acoustic House Flask/Python bot to Chatwoot's bot system.

The old bot served **three business experiences**:
- **Acoustic House** (Music retail, guitars)
- **Acoustic Shack** (Alternative retail, Bia integration)
- **Telco** (Carrier services, phone plans)

## Prerequisites

- Chatwoot instance with Apple Messages for Business support
- Access to old bot source code at `_apple/Acoustic-House-Bot-origin/`
- Rails console access
- At least one Chatwoot account created

## Migration Process

### Step 1: Analyze Old Bot Structure

Review the analysis document:

```bash
cat archive/n8n-legacy/docs/bot-migration/n8n-bot-migration-analysis.md
```

Key findings:
- 92 JSON payload files across 3 languages (en, br, jp)
- Request ID-based routing (`qr_*`, `form_*`, `lp_*`, `time_*`, etc.)
- Base64-encoded images inline (~10-50KB each)
- Python handlers in `AH.py`, `AS.py`, `telco.py`

### Step 2: Run Migration Script

The migration script will:
- Scan all JSON files in `_apple/Acoustic-House-Bot-origin/acoustichouse/json/`
- Categorize by business type
- Transform camelCase → snake_case
- Extract images to separate files
- Generate Chatwoot-compatible templates

```bash
# Dry run (preview only)
ruby script/migrate_apple_bot.rb --dry-run

# Migrate all businesses
ruby script/migrate_apple_bot.rb

# Migrate specific business only
ruby script/migrate_apple_bot.rb --business acoustic_house
ruby script/migrate_apple_bot.rb --business acoustic_shack
ruby script/migrate_apple_bot.rb --business telco
```

#### Output Structure

Migration creates:
```
tmp/bot_migration/
├── acoustic_house/
│   ├── migration_data.json      # Template definitions
│   └── images/                  # Extracted PNG images
│       ├── summary_listpicker_0.png
│       ├── summary_listpicker_1.png
│       └── ...
├── acoustic_shack/
│   ├── migration_data.json
│   └── images/
└── telco/
    ├── migration_data.json
    └── images/
```

### Step 3: Import to Chatwoot Database

The import script will:
- Create AgentBot records for each business
- Store templates in `bot_config` JSONB field
- Upload images to ActiveStorage via `AppleListPickerImage`

```bash
# Interactive (prompts for account ID)
rails runner script/import_migrated_bots.rb

# Specify account ID
rails runner script/import_migrated_bots.rb --account-id 1

# Import specific business only
rails runner script/import_migrated_bots.rb --business acoustic_house --account-id 1
```

#### What Gets Created

1. **AgentBot Records** (3 total)
   - "Acoustic House" bot
   - "Acoustic Shack" bot
   - "Telco" bot

2. **Bot Config Structure**
   ```json
   {
     "business_type": "acoustic_house",
     "migrated_at": "2025-01-01T00:00:00Z",
     "original_system": "acoustic_house_flask",
     "templates": [
       {
         "name": "lp_summary_0319_apple_list_picker",
         "request_id": "lp_summary_0319",
         "content_type": "apple_list_picker",
         "language": "en",
         "content": "Select a Feature to Learn More",
         "content_attributes": {
           "received_message": {
             "style": "small",
             "subtitle": "Key features...",
             "image_identifier": "0",
             "title": "Feature Sheet"
           },
           "list_picker": {
             "title": "Select a Feature to Learn More",
             "sections": [...],
             "multiple_selection": false
           },
           "reply_message": {
             "style": "small",
             "subtitle": "Tap this message...",
             "title": "Response"
           },
           "request_identifier": "lp_summary_0319",
           "msp_version": "1.0"
         },
         "migrated_from": "summary_listpicker.json"
       }
     ]
   }
   ```

3. **AppleListPickerImage Records**
   - One record per extracted image
   - Images stored in ActiveStorage
   - Can be referenced in templates by ID

### Step 4: Assign Bots to Inboxes

After import, configure bots via admin panel:

1. Navigate to **Settings → Agent Bots**
2. Find your migrated bots ("Acoustic House", etc.)
3. Assign to Apple Messages inboxes
4. Configure webhook URLs (if using external webhook mode)

Or via Rails console:

```ruby
# Find bot and inbox
bot = AgentBot.find_by(name: 'Acoustic House')
inbox = Inbox.find_by(channel_type: 'Channel::AppleMessagesForBusiness')

# Create assignment
AgentBotInbox.create!(
  agent_bot: bot,
  inbox: inbox,
  status: :active
)
```

### Step 5: Test Bot Flows

Test sample conversations:

1. **List Picker Flow**
   - Trigger: Send message to bot
   - Expected: Bot sends list picker with 13 feature options
   - Request ID: `lp_summary_0319`

2. **Time Picker Flow**
   - Trigger: Select "Apple Retail" option
   - Expected: Bot sends time picker with appointment slots
   - Request ID: `time_0319`

3. **Authentication Flow**
   - Trigger: Send "authenticate"
   - Expected: Bot initiates LinkedIn OAuth
   - Request ID: `auth1220181p1`

4. **Apple Pay Flow**
   - Trigger: Select product for purchase
   - Expected: Bot sends Apple Pay request
   - Request ID: `applepay_1018`

## Content Type Mapping

| Old Request ID Pattern | Chatwoot Content Type | Service |
|------------------------|----------------------|---------|
| `qr_*` | `apple_quick_reply` | Not yet implemented in Chatwoot |
| `form_*` | `apple_form` | `AppleMessagesForBusiness::FormService` |
| `lp_*` | `apple_list_picker` | `AppleMessagesForBusiness::SendListPickerService` |
| `time_*` | `apple_time_picker` | `AppleMessagesForBusiness::SendTimePickerService` |
| `auth*` | `apple_authentication` | Not yet implemented in Chatwoot |
| `applepay_*` | `apple_pay` | `AppleMessagesForBusiness::SendApplePayService` |
| `geoCode*`, `store*`, `region_*` | `apple_list_picker` | Use list picker with location data |

## Handler Migration

Python handlers (AH.py, AS.py, telco.py) need manual conversion to Rails:

### Option 1: Webhook Mode

Keep Python handlers external, configure webhook URL:

```ruby
bot = AgentBot.find_by(name: 'Acoustic House')
bot.update!(outgoing_url: 'https://your-flask-app.com/webhook')
```

Chatwoot will POST events to webhook URL.

### Option 2: Rails Service Objects

Convert Python logic to Rails services:

```ruby
# app/services/bots/acoustic_house/handler_service.rb
module Bots
  module AcousticHouse
    class HandlerService
      def initialize(conversation, request_id, selection)
        @conversation = conversation
        @request_id = request_id
        @selection = selection
      end

      def handle
        case @request_id
        when 'lp_summary_0319'
          handle_summary_selection
        when 'time_0319'
          handle_time_picker
        # ... more handlers
        end
      end

      private

      def handle_summary_selection
        # Convert Python logic to Ruby
        feature_file = feature_image_map[@selection]
        send_file(@conversation, feature_file)
      end
    end
  end
end
```

## Image Handling

### Old System
```json
{
  "data": {
    "images": [{
      "identifier": "0",
      "data": "iVBORw0KGgo..." // Base64 inline (~50KB)
    }]
  }
}
```

### New System
```ruby
# Upload image once
image = AppleListPickerImage.create!(
  account: account,
  data: File.read('path/to/image.png')
)

# Reference by ID in template
content_attributes = {
  received_message: {
    image_identifier: image.id.to_s
  }
}
```

Images are automatically:
- Stored in ActiveStorage
- Base64-encoded when sent to Apple MSP
- Cached for performance

## Troubleshooting

### Migration Script Errors

**Error**: "Could not find Acoustic-House-Bot-origin directory"
- **Fix**: Check path in `find_bot_directory` method
- Update to match your local path

**Error**: "Failed to parse JSON"
- **Fix**: Some JSON files may have syntax errors
- Review error log, fix JSON manually

### Import Script Errors

**Error**: "Account not found"
- **Fix**: Create account first or specify valid `--account-id`

**Error**: "AppleListPickerImage not found"
- **Fix**: Ensure model exists in Chatwoot
- Run: `rails db:migrate` if missing

### Case Conversion Issues

All data MUST use `AppleMessagesForBusiness::CaseTransformer`:

```ruby
# Internal storage (snake_case)
{
  'received_message' => {
    'image_identifier' => '123',
    'multiple_selection' => true
  }
}

# When sending to Apple MSP
AppleMessagesForBusiness::CaseTransformer.to_apple_format(content_attributes)
# Returns:
{
  'receivedMessage' => {
    'imageIdentifier' => '123',
    'multipleSelection' => true
  }
}
```

## Next Steps

After successful migration:

1. **Test Each Flow**
   - Acoustic House: Guitar sales flow
   - Acoustic Shack: Bia integration
   - Telco: Phone plan selection

2. **Update Webhook URLs** (if using webhook mode)
   - Point to Flask app or new Rails handlers

3. **Monitor Logs**
   ```bash
   tail -f log/production.log | grep "AgentBot"
   ```

4. **Performance Optimization**
   - Cache frequently-used templates
   - Optimize image loading
   - Monitor Apple MSP rate limits

5. **Localization**
   - Import br and jp language variants
   - Configure language detection

## Example: Full Migration Flow

```bash
# Step 1: Analyze
cat archive/n8n-legacy/docs/bot-migration/n8n-bot-migration-analysis.md

# Step 2: Migrate (dry run first)
ruby script/migrate_apple_bot.rb --dry-run
ruby script/migrate_apple_bot.rb

# Step 3: Review output
ls -la tmp/bot_migration/
cat tmp/bot_migration/acoustic_house/migration_data.json

# Step 4: Import
rails runner script/import_migrated_bots.rb --account-id 1

# Step 5: Verify
rails console
>> AgentBot.where(account_id: 1).pluck(:name)
=> ["Acoustic House", "Acoustic Shack", "Telco"]

>> bot = AgentBot.find_by(name: 'Acoustic House')
>> bot.bot_config['templates'].size
=> 25  # Number of migrated templates

# Step 6: Assign to inbox
>> inbox = Inbox.first
>> AgentBotInbox.create!(agent_bot: bot, inbox: inbox, status: :active)

# Step 7: Test!
```

## Support

For questions or issues:
- Review `archive/n8n-legacy/docs/bot-migration/n8n-bot-migration-analysis.md` (archived, n8n integration retired)
- Check migration script logs in `tmp/bot_migration/`
- Review Chatwoot bot documentation

## References

- Old bot source: `_apple/Acoustic-House-Bot-origin/`
- Chatwoot bot models: `app/models/agent_bot.rb`
- Apple Messages services: `app/services/apple_messages_for_business/`
- Case transformer: `app/services/apple_messages_for_business/case_transformer.rb`
