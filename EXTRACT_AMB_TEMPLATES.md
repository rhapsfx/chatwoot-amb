# AMB Template Extraction Script

Utility scripts to extract and recover AMB (Apple Messages for Business) template ID mappings from your database.

## Quick Start

### Option 1: Bash Wrapper (Easiest)

```bash
# List all accounts and required templates
./script/extract_amb_templates.sh 1 json

# Extract as JSON (default)
./script/extract_amb_templates.sh 1

# Extract as CSV
./script/extract_amb_templates.sh 1 csv

# Extract as SQL reference
./script/extract_amb_templates.sh 1 sql
```

### Option 2: Rails Runner (Direct)

```bash
# Discover accounts
bundle exec rails runner script/extract_amb_templates.rb

# Extract account 1 as JSON
bundle exec rails runner script/extract_amb_templates.rb 1 json

# Extract account 1 as CSV
bundle exec rails runner script/extract_amb_templates.rb 1 csv
```

## Usage Examples

### 1. **Discover Your Account ID**

If you don't know your account ID, run without arguments:

```bash
./script/extract_amb_templates.sh
```

Output:
```
📋 Available Accounts:
  ID: 1, Name: Acoustic House
  ID: 2, Name: Test Account
```

### 2. **Extract All Templates as JSON**

```bash
./script/extract_amb_templates.sh 1 json
```

Generates: `amb_templates_1_20260712_143022.json`

```json
{
  "account": {
    "id": 1,
    "name": "Acoustic House",
    "timestamp": "2026-07-12T14:30:22Z"
  },
  "summary": {
    "total_templates": 42,
    "required_found": 5,
    "required_missing": 1,
    "all_required_present": false
  },
  "required_templates": [
    {
      "id": 101,
      "name": "ah_ar_guitar",
      "status": "published",
      "created_at": "2025-10-15T08:22:00Z"
    },
    ...
  ],
  "missing_templates": [
    "ah_main_menu"
  ],
  "all_templates": [...]
}
```

### 3. **Export as CSV for Spreadsheet Analysis**

```bash
./script/extract_amb_templates.sh 1 csv
```

Generates: `amb_templates_1_20260712_143022.csv`

Open in Excel/Sheets to see all templates with their IDs, status, and dates.

### 4. **Generate SQL Reference**

```bash
./script/extract_amb_templates.sh 1 sql
```

Generates: `amb_templates_1_recovery.sql`

Contents:
```sql
-- AMB Template ID Mapping for Account 1
-- Generated: 2026-07-12T14:30:22Z
-- Required templates for AcousticHouseBot

SELECT id, name, status FROM message_templates
WHERE account_id = 1
  AND name IN (
       'ah_ar_guitar',
       'ah_guitar_info_form',
       'ah_guitar_list_picker',
       'ah_large_form_demo',
       'ah_main_menu',
       'ah_summary'
      );

-- Template ID Reference:
-- ah_ar_guitar              => ID: 101 (Status: published)
-- ah_guitar_info_form       => ID: 102 (Status: draft)
-- ah_guitar_list_picker     => ID: 103 (Status: published)
-- ah_large_form_demo        => ID: 104 (Status: published)
-- ah_main_menu              => (Missing)
-- ah_summary                => ID: 106 (Status: published)
```

## Output Format Details

### JSON Format
Contains:
- Account metadata
- Summary of found/missing templates
- Detailed list of required templates
- List of missing templates
- All templates in the account (for cross-reference)

**Best for:** Programmatic processing, API integrations, detailed analysis

### CSV Format
Columns:
- Template ID
- Template Name
- Status (draft/published)
- Created At
- Updated At
- Is Required (Yes/No)
- Found (Yes/No)

**Best for:** Spreadsheet analysis, quick visual review, team sharing

### SQL Format
Includes:
- SELECT query to verify templates exist
- SQL comments mapping template names to IDs
- Ready to copy/paste into database tools

**Best for:** Database recovery, direct SQL queries, documentation

## Required AMB Templates

The AcousticHouseBot requires these 6 templates:

| Name | Purpose |
|------|---------|
| `ah_ar_guitar` | AR guitar experience display |
| `ah_guitar_info_form` | Customer information form |
| `ah_guitar_list_picker` | Guitar selection list picker |
| `ah_large_form_demo` | Complex form demo |
| `ah_main_menu` | Main menu navigation |
| `ah_summary` | Summary list picker |

## Troubleshooting

### "bundle command not found"
```bash
cd /path/to/chatwoot
bundle install
```

### "Account X not found"
Run without arguments to see available accounts:
```bash
./script/extract_amb_templates.sh
```

### "No Rails environment loaded"
Make sure you're in the Chatwoot root directory:
```bash
cd /path/to/chatwoot
./script/extract_amb_templates.sh 1 json
```

### Checking Results

After running the script, verify templates were found:

```bash
# Quick check
cat amb_templates_1_*.json | grep -A2 "summary"

# Or open in your editor
code amb_templates_1_*.json
```

## Using Results to Recover Templates

If templates are missing, you have several options:

### 1. **Check Backups**
Look in your database backups for the template definitions:

```bash
grep -r "ah_guitar_list_picker" /path/to/database/backups/
```

### 2. **Use SQL File to Verify**
Run the generated SQL file to confirm which templates exist:

```bash
psql -U chatwoot_user -d chatwoot_production \
  -f amb_templates_1_recovery.sql
```

### 3. **Recreate Missing Templates**

If templates are completely lost, recreate them through the UI:
1. Go to Super Admin → Templates
2. Create new templates with the exact names from the output
3. Re-run this script to get the new IDs

### 4. **Restore from Backup**

If you have a database backup, restore template data:

```bash
# Find template export from backup
SELECT * FROM message_templates 
WHERE account_id = 1 
AND name IN ('ah_guitar_list_picker', 'ah_guitar_info_form', ...);
```

## Script Source

Located in:
- **Ruby script:** `/script/extract_amb_templates.rb`
- **Bash wrapper:** `/script/extract_amb_templates.sh`
- **This guide:** `/EXTRACT_AMB_TEMPLATES.md`

## Questions?

Check the template facade and bot message sender code:
- [TemplateFacade](app/services/apple_messages_for_business/template_facade.rb)
- [BotMessageSender](app/services/apple_messages_for_business/bot_message_sender.rb)
- [AcousticHouseBotService](app/services/apple_messages_for_business/acoustic_house_bot_service.rb)
