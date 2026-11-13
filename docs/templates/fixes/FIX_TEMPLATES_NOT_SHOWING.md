# Fix: Templates Not Showing in Chatwoot UI

## 🔍 The Problem

The imported templates were stored in `AgentBot.bot_config['templates']` but Chatwoot's UI displays templates from the **`message_templates` table**, not from bot_config.

## ✅ The Solution

Use the new import script that creates **MessageTemplate** records:

```bash
rails runner script/import_as_message_templates.rb --account-id 1 --business acoustic_house
```

## 📊 Comparison

### ❌ Old Import Script (`import_migrated_bots.rb`)

**Stores in**: `AgentBot.bot_config['templates']` (JSONB field)

**Structure**:
```ruby
bot = AgentBot.find_by(name: 'Acoustic House')
bot.bot_config['templates'] = [
  { name: 'template1', content: '...' },
  { name: 'template2', content: '...' }
]
```

**Visible in UI**: ❌ **NO** - bot_config is not displayed in templates UI

**Use case**: Webhook bots with external template management

### ✅ New Import Script (`import_as_message_templates.rb`)

**Stores in**: `message_templates` table (proper database records)

**Structure**:
```ruby
MessageTemplate.create!(
  account_id: 1,
  name: 'wismo_order_confirmed',
  category: 'notification',
  supported_channels: ['Channel::AppleMessagesForBusiness'],
  metadata: { apple_message_content: {...} },
  content_blocks: [...]
)
```

**Visible in UI**: ✅ **YES** - appears in Settings → Message Templates

**Use case**: Chatwoot native templates with UI management

## 🚀 How to Fix Your Import

### Step 1: Run New Import Script

```bash
# Dry-run first (always!)
rails runner script/import_as_message_templates.rb \
  --account-id 1 \
  --business acoustic_house \
  --dry-run

# If preview looks good, run actual import
rails runner script/import_as_message_templates.rb \
  --account-id 1 \
  --business acoustic_house
```

### Step 2: Verify in UI

1. **Open Chatwoot**
2. **Go to**: Settings → Message Templates
3. **You should see**: Your imported templates with tags like:
   - `acoustic_house`
   - `apple_list_picker`
   - `migrated`

### Step 3: Test in Conversation

1. **Open a conversation** (Apple Messages inbox)
2. **Click template icon** (or type `/`)
3. **Search** for your templates
4. **Send** to customer

## 📋 What Gets Created

### MessageTemplate Record

```ruby
MessageTemplate {
  id: 1,
  account_id: 1,
  name: "wismo_order_confirmed_714C2504",
  category: "notification",
  description: "Migrated from acoustic_house bot - wismo.orderConfirmed.orderImage",
  status: "active",
  supported_channels: ["Channel::AppleMessagesForBusiness"],
  tags: ["acoustic_house", "text", "migrated"],
  use_cases: ["general_communication"],
  version: 1,
  metadata: {
    migrated_from: "acoustic_house",
    original_file: "wismo.orderConfirmed.orderImage",
    request_id: "714C2504-547C-4094-BF67-A757B3E168C6",
    original_content_type: "text",
    language: "en",
    apple_message_content: {
      content: "Your guitar order has been confirmed!",
      content_type: "text",
      content_attributes: {...}
    }
  }
}
```

### TemplateContentBlock

```ruby
TemplateContentBlock {
  id: 1,
  message_template_id: 1,
  block_type: "text",
  properties: {
    # Content attributes from old bot
    ...
  },
  order_index: 0
}
```

### TemplateChannelMapping

```ruby
TemplateChannelMapping {
  id: 1,
  message_template_id: 1,
  channel_type: "Channel::AppleMessagesForBusiness",
  content_type: "text",
  field_mappings: {
    "content" => "...",
    "content_attributes" => {...}
  }
}
```

## 🔍 Verify Import in Rails Console

```ruby
rails console

# Check templates were created
>> MessageTemplate.where(tags: ['acoustic_house']).count
=> 93  # Number of core templates

# Get first template
>> template = MessageTemplate.where(tags: ['acoustic_house']).first
>> template.name
=> "wismo_order_confirmed_714C2504"

# Check metadata
>> template.metadata['apple_message_content']
=> {
  "content" => "Your guitar order has been confirmed!",
  "content_type" => "text",
  "content_attributes" => {...}
}

# Check content blocks
>> template.content_blocks.count
=> 1

>> template.content_blocks.first.properties
=> { ... } # The actual content attributes
```

## 📱 Using Templates in UI

### In Settings
1. Navigate to **Settings → Message Templates**
2. You'll see a list of all templates
3. Filter by:
   - **Category**: notification, scheduling, payment, etc.
   - **Tags**: `acoustic_house`, `migrated`
   - **Channel**: Apple Messages for Business

### In Conversations
1. Open an **Apple Messages conversation**
2. Click the **template button** (📋 icon)
3. **Search** by name or tag
4. **Select** template
5. **Fill parameters** (if any)
6. **Send!**

## 🎯 Quick Commands

```bash
# Import core templates (filtered version - recommended)
rails runner script/import_as_message_templates.rb --account-id 1 --business acoustic_house

# Import all templates (unfiltered - for testing)
# First, edit migration_file path in script to use migration_data.json instead of migration_data_CORE.json

# Dry-run first
rails runner script/import_as_message_templates.rb --account-id 1 --business acoustic_house --dry-run

# Delete imported templates (if needed)
rails runner "MessageTemplate.where(tags: ['acoustic_house', 'migrated']).destroy_all"
```

## 🔄 Migration Comparison

| Aspect | Old Script (bot_config) | New Script (MessageTemplate) |
|--------|------------------------|------------------------------|
| **Storage** | JSONB in agent_bots | message_templates table |
| **UI Visibility** | ❌ Not visible | ✅ Visible in Settings |
| **Searchable** | ❌ No | ✅ Yes (by name, tag, category) |
| **Usable in Conversations** | ❌ No UI integration | ✅ Full UI support |
| **Database Structure** | Flat JSON | Proper relations (content_blocks, mappings) |
| **Recommended For** | External webhooks | Chatwoot native bots |

## ⚠️ Important Notes

### 1. Use Filtered Core Templates

The script automatically looks for `migration_data_CORE.json` first (93 core templates), which is **recommended** for production.

If you want all 575 templates (including tests):
- Edit the script or rename `migration_data.json` → `migration_data_CORE.json`

### 2. Categories Available

MessageTemplate categories:
- `general`
- `payment`
- `scheduling`
- `support`
- `marketing`
- `feedback`
- `notification`
- `confirmation`
- `sales`

### 3. Tags for Filtering

Each template gets tagged with:
- Business name: `acoustic_house`, `acoustic_shack`, `telco`
- Content type: `apple_list_picker`, `apple_time_picker`, etc.
- Source: `migrated`

Search in UI: "tag:acoustic_house tag:migrated"

## 🚀 Complete Workflow

```bash
# 1. Migrate JSON payloads
ruby script/migrate_apple_bot.rb --business acoustic_house

# 2. Filter core vs test
ruby script/filter_core_templates.rb --business acoustic_house

# 3. Import as MessageTemplates (DRY-RUN!)
rails runner script/import_as_message_templates.rb \
  --account-id 1 \
  --business acoustic_house \
  --dry-run

# 4. If preview looks good, import for real
rails runner script/import_as_message_templates.rb \
  --account-id 1 \
  --business acoustic_house

# 5. Check in UI
# Settings → Message Templates
# Filter by tag: "acoustic_house"
```

## 📚 Files Summary

| Script | Purpose | Output Location |
|--------|---------|-----------------|
| `migrate_apple_bot.rb` | Extract from old bot | tmp/bot_migration/ |
| `filter_core_templates.rb` | Separate core vs test | migration_data_CORE.json |
| ~~`import_migrated_bots.rb`~~ | ❌ bot_config (not visible) | AgentBot table |
| **`import_as_message_templates.rb`** | ✅ **UI-visible templates** | **message_templates table** |

## ✅ Success Checklist

After running the new import script:

- [ ] Run new import script
- [ ] Open Chatwoot UI
- [ ] Go to Settings → Message Templates
- [ ] See imported templates with "acoustic_house" tag
- [ ] Open a conversation
- [ ] Click template button
- [ ] Search for templates
- [ ] Send test template
- [ ] Verify message appears correctly

Your templates should now be **visible and usable** in the Chatwoot UI! 🎉
