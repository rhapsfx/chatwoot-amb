# Apple Messages Bot Migration Analysis

## Overview
This document analyzes the old Acoustic House Bot (Flask/Python) and provides migration guidance to Chatwoot bot system.

## Old Bot Architecture

### Business Experiences
The bot served **three distinct business experiences**:

1. **Acoustic House (AH)** - Music retail, guitar sales
2. **Acoustic Shack (AS)** - Alternative retail, Bia integration
3. **Telco** - Carrier services, phone plans

### Request ID Routing Patterns

#### Quick Reply (`qr_*`)
- `qr_travel` → Travel preferences
- `qr_name` → Name collection
- `qr_view_ar` / `qr_place_ar` → AR experiences
- `qr_continue` → Flow continuation
- `qr_learn_more` → Feature details
- `qr_photo` → Photo sharing

#### Forms (`form_*`)
- `form_help_me_decide` → Decision tree
- `form_covid_quest` → COVID questionnaire
- `form_bia_ah` → Bia integration form

#### List Pickers (`lp_*`)
- `lp_guitar_0319` → Guitar selection
- `lp_summary_0319` → Feature summary (13 items)
- `lp_menu_0319` → Main menu
- `lp_startover_1018` → Restart flow

#### Time Pickers (`time_*`)
- `time_1218` → Appointment scheduling (old)
- `time_0319` → Appointment scheduling (new)

#### Authentication (`auth*`)
- `auth1220181p1` → LinkedIn OAuth flow
- `linkedin_server_side` → Server-side auth
- `linkedin_response` → Auth callback

#### Apple Pay (`applepay_*`)
- `applepay_1018` → Payment request flow

#### Location/Maps
- `geoCode0504` → Geocoding
- `store0419` → Store locator
- `region_0506` → Region selection

### JSON Payload Structure

#### Example: List Picker (summary_listpicker.json)
```json
{
  "receivedMessage": {
    "style": "small",
    "subtitle": "Key features that you were exposed to.",
    "imageIdentifier": "0",
    "title": "Feature Sheet"
  },
  "bid": "com.apple.messages.MSMessageExtensionBalloonPlugin:0000000000:com.apple.icloud.apps.messages.business.extension",
  "data": {
    "images": [
      {
        "identifier": "0",
        "data": "iVBORw0KGgoAAAAN..." // base64
      }
    ],
    "mspVersion": "1.0",
    "listPicker": {
      "title": "Select a Feature to Learn More",
      "sections": [
        {
          "items": [
            {
              "title": "1. Apple Pay",
              "identifier": "1",
              "imageIdentifier": "1",
              "order": 1
            }
          ]
        }
      ],
      "multipleSelection": false
    },
    "requestIdentifier": "lp_summary_0319"
  },
  "replyMessage": {
    "style": "small",
    "subtitle": "Tap this message to view your selection",
    "title": "Response"
  }
}
```

### Key Observations

1. **Images**: Base64-encoded directly in JSON (~10-50KB per image)
2. **Case Convention**: camelCase (Apple format) vs snake_case (Rails)
3. **Request IDs**: String-based routing keys
4. **Localization**: Separate folders `/json/en/`, `/json/br/`, `/json/jp/`

## Chatwoot Bot Architecture

### Models
- **AgentBot**: Core bot model with webhook support
- **bot_config**: JSONB field for configuration
- **bot_type**: Enum (currently only `webhook: 0`)

### Services
- **Templates::BotMessagingService**: Send template messages
- **Templates::BotRendererService**: Render templates for channels
- **AppleMessagesForBusiness::MessageProcessorService**: URL-to-Rich Link conversion

### Content Types (Apple Messages)
- `apple_list_picker`
- `apple_time_picker`
- `apple_quick_reply`
- `apple_pay`
- `apple_rich_link`
- `apple_authentication`
- `apple_form`
- `apple_custom_app`

### CaseTransformer
**CRITICAL**: ALL Apple Messages data MUST use `AppleMessagesForBusiness::CaseTransformer`:
- **Storage**: snake_case (Rails convention)
- **Frontend**: camelCase (JavaScript convention)
- **Apple MSP API**: camelCase (Apple convention)

```ruby
# Example transformation
AppleMessagesForBusiness::CaseTransformer.to_apple_format({
  'image_identifier' => 'img1',
  'multiple_selection' => true
})
# Returns: { 'imageIdentifier' => 'img1', 'multipleSelection' => true }
```

## Migration Mapping

### Old → New Content Types

| Old Request ID Pattern | New Content Type | Chatwoot Service |
|------------------------|------------------|------------------|
| `qr_*` | `apple_quick_reply` | QuickReplyService |
| `form_*` | `apple_form` | FormService |
| `lp_*` | `apple_list_picker` | SendListPickerService |
| `time_*` | `apple_time_picker` | SendTimePickerService |
| `auth*` | `apple_authentication` | AuthenticationService |
| `applepay_*` | `apple_pay` | SendApplePayService |

### Image Handling

**Old**: Base64 in JSON → **New**: ActiveStorage with AppleListPickerImage model

```ruby
# Old:
{
  "data": {
    "images": [{
      "identifier": "0",
      "data": "iVBORw0KGgo..." # base64 inline
    }]
  }
}

# New:
image = AppleListPickerImage.create!(
  account: account,
  data: base64_data # Automatically stored in ActiveStorage
)
# Reference by identifier in content_attributes
```

### Database Changes Needed

1. **Bot Templates Table** (if not exists):
```sql
CREATE TABLE bot_templates (
  id BIGSERIAL PRIMARY KEY,
  account_id BIGINT REFERENCES accounts(id),
  agent_bot_id BIGINT REFERENCES agent_bots(id),
  name VARCHAR NOT NULL,
  category VARCHAR, -- 'acoustic_house', 'acoustic_shack', 'telco'
  content_type VARCHAR NOT NULL,
  content JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);
```

2. **Bot Flow Mappings** (optional):
```sql
CREATE TABLE bot_flow_mappings (
  id BIGSERIAL PRIMARY KEY,
  old_request_id VARCHAR NOT NULL, -- 'lp_summary_0319'
  new_template_id BIGINT REFERENCES bot_templates(id),
  business_type VARCHAR, -- 'acoustic_house', 'acoustic_shack', 'telco'
  created_at TIMESTAMP NOT NULL
);
```

## Migration Strategy

### Phase 1: Data Extraction
1. Scan `/json/` directories for all payload files
2. Categorize by business type (AH, AS, Telco)
3. Extract images and store in ActiveStorage
4. Map request IDs to content types

### Phase 2: Transformation
1. Convert camelCase → snake_case for storage
2. Transform base64 images → ActiveStorage references
3. Create Chatwoot template format
4. Validate with CaseTransformer

### Phase 3: Import
1. Create AgentBot records for each business
2. Import templates as bot_config or separate table
3. Create flow mappings for request IDs
4. Test round-trip conversion

### Phase 4: Handler Migration
1. Extract Python handler logic from AH.py, AS.py, telco.py
2. Convert to Rails service objects
3. Map to webhook callbacks or inline logic
4. Test with sample conversations

## Next Steps

1. Run migration script to analyze all JSON files
2. Create separate imports for AH, AS, Telco
3. Document unmapped features
4. Create test suite for migrated flows
