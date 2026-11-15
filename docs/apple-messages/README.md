# Apple Messages for Business Integration

This directory contains all documentation, scripts, and data files related to the Apple Messages for Business (AMB) integration in Chatwoot.

## IMPORTANT: Image Architecture Migration (November 2025)

**NEW ARCHITECTURE**: Chatwoot now supports a two-tier image architecture:
- **SharedAppleImage** - Account-wide images (system, branding, template)
- **AppleListPickerImage** - Inbox-specific images (custom, overrides)

**OLD SCRIPTS DEPRECATED**: Scripts that hardcode `inbox_id` for system/branding images are deprecated and will be removed in Q2 2026.

**Migration Path**:
- See `DEPRECATION_TIMELINE.md` for deprecation schedule
- See `IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md` for technical details
- Use `SharedAppleImage.create!` for new image uploads
- Run migration scripts: `migrate_system_images_to_shared.rb`, `migrate_branding_images_to_shared.rb`

**Quick Example**:
```ruby
# OLD (DEPRECATED)
AppleListPickerImage.create!(
  inbox_id: 5,  # Hardcoded - BAD!
  identifier: 'messages_png',
  image: File.open('Messages.png')
)

# NEW (RECOMMENDED)
SharedAppleImage.create!(
  account_id: 1,
  identifier: 'messages_png',
  image_type: 'system',
  description: 'Messages app icon',
  image: File.open('Messages.png')
)
```

## Directory Structure

Counts, not a file-by-file dump — the previous listing drifted within weeks.
List an area with `ls` or read its guide.

```
docs/apple-messages/
├── README.md                    # this file (index for the whole area)
├── START_HERE.md                # Acoustic House bot: implementation completion report
├── APPLE_PAY_GUIDE.md           # Apple Pay integration (merchant, gateway, checklist)
├── APPLE_PAY_TEST_MODE.md       # exercising Apple Pay in test mode
├── APPLE_WALLET_GUIDE.md        # Wallet passes (certificates, templates)
├── case-normalization-specification.md   # CaseTransformer rules — read before any AMB change
├── guides/            (6 files) # OAuth2/applepay configuration, troubleshooting, channel setup, migration, webhook deployment, template creation
├── implementation/   (21 files) # design docs + implementation plans (images, list picker, typing indicator, payload validation, …)
├── reports/           (1 file)  # APPLE_MSP_MISSING_FEATURES_CHECKLIST.md
├── fixes/             (2 files) # bot API time-picker fix, timeslot preservation logic
├── bot-service/       (2 files) # current Ruby bot service: overview + technical guide
├── scripts/          (12 files) # test/, utilities/, normalization analyzers + rollback
└── data/              (4 files) # sample payloads and MSP test results
```

The remaining ~43 topic docs at this level cover individual features
(`IMAGE_*.md`, `SHARED_*.md`, `LIST_PICKER_*`, `TIME_PICKER_*`,
`PHASE_*`, `ACOUSTIC_HOUSE_*`, …). See "Key Documentation" below for the
essential entry points.

## Key Documentation

### Essential Guides (Start Here)

1. **APPLE_PAY_GUIDE.md** - Complete Apple Pay integration guide
   - Merchant registration and validation
   - Payment gateway setup (Stripe, Adyen)
   - End-to-end implementation with examples
   - Production deployment checklist

2. **case-normalization-specification.md** - CaseTransformer technical specification
   - Critical for ALL AMB feature development
   - Snake_case vs camelCase conversion rules
   - Usage patterns and best practices

3. **guides/APPLE_MESSAGES_OAUTH2_APPLEPAY_CONFIGURATION_GUIDE.md** - Initial setup
   - OAuth2 configuration
   - Apple Pay Business Chat setup
   - Webhook configuration

### Implementation References

4. **implementation/APPLE_MSP_COMPLETE_IMPLEMENTATION_GUIDE.md** - Complete AMB integration
5. **implementation/APPLE_MSP_OUTGOING_SERVICES.md** - Service architecture
6. **implementation/APPLE_WEBHOOK_REFACTORING.md** - Webhook patterns
7. **implementation/PAYLOAD_VALIDATION_IMPLEMENTATION.md** - Validation patterns

### Migration and Deployment

8. **guides/MIGRATION_GUIDE.md** - CaseTransformer migration procedures
9. **guides/WEBHOOK_DEPLOYMENT_GUIDE.md** - Production webhook deployment
10. **phases/PHASE_1_COMPLETE.md** - CaseTransformer implementation details
11. **phases/MIGRATION_IMPLEMENTATION_COMPLETE.md** - Database migration guide

### Status and Analysis

12. **reports/APPLE_MSP_MISSING_FEATURES_CHECKLIST.md** - Implementation status
13. **reports/APPLE_MESSAGES_I18N_REPORT.md** - Internationalization analysis

## Quick Start

### 1. Initial Setup
Start with the OAuth2 and Apple Pay configuration:
```bash
# Read the configuration guide
cat docs/apple-messages/guides/APPLE_MESSAGES_OAUTH2_APPLEPAY_CONFIGURATION_GUIDE.md
```

### 2. Apple Pay Integration
Follow the unified Apple Pay guide:
```bash
# Complete Apple Pay setup (1462-line comprehensive guide)
cat docs/apple-messages/APPLE_PAY_GUIDE.md
```

### 3. Understanding CaseTransformer (CRITICAL)
Before adding ANY new AMB features, read the case normalization spec:
```bash
# CaseTransformer technical specification
cat docs/apple-messages/case-normalization-specification.md

# Migration guide for implementing new features
cat docs/apple-messages/guides/MIGRATION_GUIDE.md
```

### 4. Implementation
Follow the main implementation plan:
```bash
# Complete implementation guide
cat docs/apple-messages/implementation/APPLE_MESSAGES_FOR_BUSINESS_INTEGRATION_PLAN.md

# Service architecture reference
cat docs/apple-messages/implementation/APPLE_MSP_OUTGOING_SERVICES.md
```

### 5. Testing
Use the test scripts to validate your implementation:
```bash
# Main integration test
./docs/apple-messages/scripts/test/test_apple_integration.sh

# Check configuration
ruby docs/apple-messages/scripts/utilities/check_apple_config.rb

# Verify normalization
ruby docs/apple-messages/scripts/verify_normalization.rb
```

### 6. Troubleshooting
Refer to the troubleshooting guide for common issues:
```bash
cat docs/apple-messages/guides/APPLE_MESSAGES_TROUBLESHOOTING_GUIDE.md
```

## Key Implementation Files

### Backend Integration
- **Channel model**: `app/models/channel/apple_messages_for_business.rb`
- **Webhook controller**: `app/controllers/webhooks/apple_messages_for_business_controller.rb`
- **Services**: `app/services/apple_messages_for_business/`
  - `send_message_service.rb` - Base message sender
  - `send_list_picker_service.rb` - List picker with images
  - `send_time_picker_service.rb` - Time picker with images
  - `form_service.rb` - Forms with images
  - `send_rich_link_service.rb` - Rich links
  - `case_transformer.rb` - **CRITICAL**: Snake_case ↔ camelCase converter
- **Jobs**: `app/jobs/apple_messages_for_business/`
- **Models**:
  - `app/models/apple_list_picker_image.rb` - List picker image storage
  - `app/models/message_template.rb` - Template storage

### Frontend Integration
- **Channel setup**: `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/AppleMessagesForBusiness.vue`
- **Message bubbles**: `app/javascript/dashboard/components-next/message/bubbles/Apple*.vue`
- **Modals**:
  - `EnhancedTimePickerModal.vue` - Time picker with image support
  - `AppleFormBuilder.vue` - Form builder with Messages tab
- **Composers**: `app/javascript/dashboard/components/widgets/conversation/ReplyBox/AppleMessagesComposer.vue`
- **Rich link helper**: `app/javascript/dashboard/helper/appleMessagesRichLink.js`

## CaseTransformer: Critical System Component

**ALL Apple Messages features MUST use CaseTransformer for case conversions.**

### Why CaseTransformer?
- **Internal storage**: Always snake_case (Rails convention)
- **Frontend**: Naturally sends camelCase (JavaScript convention)
- **Apple MSP API**: Requires camelCase
- **Automatic normalization**: API layer converts camelCase → snake_case
- **Service layer**: CaseTransformer converts snake_case → camelCase for Apple

### Implementation Status
- ✅ Phase 1: CaseTransformer module + API normalization (Oct 2025)
- ✅ Phase 2: Database migration - 265 records normalized to 100% (Oct 2025)
- ✅ Phase 3: Service layer cleanup - All dual-checks removed (Oct 2025)

### Adding New Features
When implementing new AMB features:

1. **Store data in snake_case** in `content_attributes`
2. **Use CaseTransformer** in services before sending to Apple MSP
3. **Add new field mappings** to `case_transformer.rb` if needed
4. **Never use dual-checks**: `field['snake'] || field['camel']` ❌

See `case-normalization-specification.md` and `guides/MIGRATION_GUIDE.md` for details.

## Testing

### Integration Tests
```bash
# Main integration test suite
./docs/apple-messages/scripts/test/test_apple_integration.sh

# Test message delivery
ruby docs/apple-messages/scripts/test/test_apple_message_delivery.rb

# Test webhook endpoint
ruby docs/apple-messages/scripts/test/test_webhook_endpoint.rb
```

### Configuration Checks
```bash
# Check Apple Messages configuration
ruby docs/apple-messages/scripts/utilities/check_apple_config.rb

# Check Apple channels
ruby docs/apple-messages/scripts/utilities/check_apple_channels.rb

# Verify database normalization
ruby docs/apple-messages/scripts/verify_normalization.rb
```

### Debug Utilities
```bash
# Debug API responses
ruby docs/apple-messages/scripts/debug/debug_api_response.rb

# Debug attachments
ruby docs/apple-messages/scripts/debug/debug_attachment.rb

# Debug time picker payloads
ruby docs/apple-messages/scripts/debug/debug_time_picker_payload.rb

# Test typing indicator
ruby docs/apple-messages/scripts/debug/test_apple_typing_indicator.rb
```

### CaseTransformer Tests
```bash
# Dry run normalization analysis
ruby docs/apple-messages/scripts/dry_run_normalization.rb

# Verify normalization status
ruby docs/apple-messages/scripts/verify_normalization.rb

# RSpec tests
bundle exec rspec spec/services/apple_messages_for_business/case_transformer_spec.rb
```

## Data Files

Sample payloads and test results are stored in `data/` for reference and testing purposes:
- `apple_messages_payloads.json` - Original Apple MSP payloads
- `corrected_apple_messages_payloads.json` - Normalized payloads
- `corrected_msp_test_results.json` - Test results
- `final_msp_test_results.json` - Final validation results

## Current Status

### Completed Features
- ✅ Basic messaging and media attachments
- ✅ Rich links with favicon support
- ✅ List picker with images
- ✅ Time picker with images
- ✅ Forms with images (receivedMessage/replyMessage)
- ✅ OAuth2 authentication
- ✅ Apple Pay integration (complete guide)
- ✅ CaseTransformer system (Phases 1-3)
- ✅ Typing indicator support
- ✅ Webhook JWT validation
- ✅ Interactive Data Request (IDR) support

### In Progress
See `reports/APPLE_MSP_MISSING_FEATURES_CHECKLIST.md` for:
- Missing Apple MSP features
- Planned enhancements
- Technical debt items

## Documentation Organization

### By Topic
- **Setup**: `guides/APPLE_MESSAGES_OAUTH2_APPLEPAY_CONFIGURATION_GUIDE.md`
- **Apple Pay**: `APPLE_PAY_GUIDE.md` (unified, comprehensive)
- **CaseTransformer**: `case-normalization-specification.md`, `guides/MIGRATION_GUIDE.md`
- **Webhooks**: `guides/WEBHOOK_DEPLOYMENT_GUIDE.md`, `implementation/APPLE_WEBHOOK_REFACTORING.md`
- **Templates**: `guides/APPLE_MESSAGES_TEMPLATE_CREATION.md`

### By Phase
- **Planning**: `implementation/APPLE_MESSAGES_FOR_BUSINESS_INTEGRATION_PLAN.md`
- **Phase 1**: `implementation/APPLE_MSP_PHASE_1_IMPLEMENTATION.md`, `phases/PHASE_1_COMPLETE.md`
- **Phase 2**: `phases/MIGRATION_IMPLEMENTATION_COMPLETE.md`
- **Phase 3**: `phases/PHASE_3_COMPLETE.md`

### By Type
- **Guides**: User-facing configuration and troubleshooting
- **Implementation**: Technical implementation details
- **Reports**: Analysis and status tracking
- **Phases**: Completion reports and retrospectives
- **Fixes**: Bug fixes and patches

## Contributing

When adding new documentation:

1. **Place in correct directory**:
   - User guides → `guides/`
   - Technical implementation → `implementation/`
   - Bug fixes → `fixes/`
   - Status reports → `reports/`
   - Phase completion → `phases/`

2. **Update this README** with new files in the directory structure

3. **Follow naming conventions**:
   - Use UPPER_SNAKE_CASE.md for documentation files
   - Prefix with topic (e.g., `APPLE_PAY_`, `APPLE_MSP_`)

4. **Link related documentation**:
   - Cross-reference related guides
   - Update implementation checklists
   - Add to "Key Documentation" section if essential

## Support

For issues or questions:
1. Check `guides/APPLE_MESSAGES_TROUBLESHOOTING_GUIDE.md`
2. Review `reports/APPLE_MSP_MISSING_FEATURES_CHECKLIST.md` for known limitations
3. Check phase completion reports in `phases/` for implementation details
4. Use debug scripts in `scripts/debug/` to diagnose issues
