# Apple Messages for Business - Payload Validation Implementation

## Overview

This document describes the pre-send payload validation system implemented for Apple Messages for Business to ensure all payloads are valid before being sent to `mspgw.apple.com`.

## Implementation Date

October 27, 2025

## Components

### 1. PayloadValidatorService

**Location**: `app/services/apple_messages_for_business/payload_validator_service.rb`

**Purpose**: Validates Apple Messages payloads before sending to Apple MSP gateway.

**Features**:
- ✅ Validates payload structure (required fields, types, versions)
- ✅ Validates ISO 8601 date formats in time picker timeslots
- ✅ Validates base64 image encoding and size limits
- ✅ Validates message-type-specific requirements
- ✅ Logs detailed payload summaries for debugging
- ✅ Raises `ValidationError` with detailed error messages

**Supported Message Types**:
- `apple_list_picker` - Validates sections, items, images, identifiers
- `apple_time_picker` - Validates event structure, timeslots, ISO 8601 dates
- `apple_quick_reply` - Validates 2-5 items with identifiers and titles
- `apple_form` - Validates pages, page identifiers, types, titles
- `apple_custom_app` - Validates basic interactive message structure
- `text` - Validates body field presence

### 2. Integration Points

The validation hook is integrated into three services that send messages to Apple:

#### SendMessageService
**Location**: `app/services/apple_messages_for_business/send_message_service.rb`
**Method**: `send_to_apple_gateway` (line 760)
**Validates**: All interactive messages (list picker, time picker, quick reply, forms, custom apps)

#### FormService
**Location**: `app/services/apple_messages_for_business/form_service.rb`
**Method**: `send_to_apple_gateway` (line 296)
**Validates**: Apple MSP form messages

#### CustomExtensionService
**Location**: `app/services/apple_messages_for_business/custom_extension_service.rb`
**Method**: `send_to_apple_gateway` (line 117)
**Validates**: Custom iMessage app invocation messages

## Validation Flow

```
Message Creation (ReplyBox/BOT API/UI Templates)
    ↓
API Controller (auto-normalizes camelCase → snake_case)
    ↓
MessageBuilder.perform
    ↓
Message.save! ← ContentAttributeValidator (database-level validation)
    ↓
Service Layer (FormService, SendMessageService, etc.)
    ↓
build_apple_msp_payload (constructs payload)
    ↓
send_to_apple_gateway
    ↓
PayloadValidatorService.validate! ← PRE-SEND VALIDATION
    ↓
If valid → HTTParty.post to mspgw.apple.com
If invalid → Return error response (400) without sending
```

## Validation Checks

### 1. Payload Structure Validation

**Required Top-Level Fields**:
- `v` (version, must be 1)
- `id` (message ID)
- `sourceId` (business ID)
- `destinationId` (user ID)
- `type` (must be 'text' or 'interactive')

**Text Messages**:
- `body` field required

**Interactive Messages**:
- `interactiveData` required
- `interactiveData.bid` required
- `interactiveData.data` required

### 2. ISO 8601 Date Validation

**Applies to**: Time picker timeslots

**Valid Formats**:
- `2024-01-15T14:30:00+0000` (with timezone)
- `2024-01-15T14:30:00Z` (UTC)
- `2024-01-15T14:30:00` (local time)

**Validation**:
- Regex pattern match: `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}([+-]\d{4}|Z)?$`
- Parseable by `Time.parse`

### 3. Base64 Image Validation

**Applies to**: All interactive messages with images

**Checks**:
- Image has `identifier` field
- Image has `data` field
- Data is valid base64 (A-Z, a-z, 0-9, +, /, = padding)
- Decoded size ≤ 10MB (Apple's limit)

**Validation**:
- Base64 regex: `^[A-Za-z0-9+\/]*={0,2}$`
- Decodable by `Base64.strict_decode64`

### 4. Message-Type-Specific Validation

#### List Picker
- At least one section
- Each section has items array
- Each item has identifier and title
- Style values: 'icon', 'small', or 'large'

#### Time Picker
- Event structure present
- At least one timeslot
- Each timeslot has identifier, startTime, duration
- StartTime in ISO 8601 format

#### Quick Reply
- 2-5 items (Apple MSP requirement)
- Each item has identifier and title

#### Form
- At least one page
- Each page has pageIdentifier, type, title

## Error Handling

### Validation Failure

When validation fails:

1. **Error Logged**:
   ```
   [AMB PayloadValidator] Payload validation failed: <error details>
   [AMB Send] Invalid payload: <full JSON payload>
   ```

2. **Response Returned**:
   ```ruby
   OpenStruct.new(
     success?: false,
     code: 400,
     body: { error: 'Payload validation failed', details: <error message> }.to_json
   )
   ```

3. **No Request to Apple**: Payload is NOT sent to `mspgw.apple.com`

### Validation Success

When validation passes:

1. **Success Logged**:
   ```
   [AMB PayloadValidator] ✅ Payload validation passed
   [AMB PayloadValidator] Payload summary: <JSON summary>
   ```

2. **Payload Summary Includes**:
   - Message type
   - Payload size (bytes)
   - Image count
   - Type-specific metrics (section count, timeslot count, etc.)

3. **Request Proceeds**: Payload sent to Apple MSP gateway

## Payload Summary Logging

The validator logs detailed summaries for debugging:

```json
{
  "type": "interactive",
  "message_type": "apple_list_picker",
  "payload_size": 15234,
  "has_images": true,
  "image_count": 3,
  "section_count": 2,
  "total_items": 8
}
```

## Testing

### Manual Testing

Test the validation with invalid payloads:

```ruby
# In Rails console
channel = Channel::AppleMessagesForBusiness.first
message = Message.new(content_type: 'apple_time_picker', content_attributes: {
  event: {
    timeslots: [
      { identifier: '1', startTime: 'invalid-date', duration: 3600 }
    ]
  }
})

service = AppleMessagesForBusiness::SendMessageService.new(
  channel: channel,
  destination_id: 'test_user',
  message: message
)

# This should fail validation and log errors
result = service.send(:send_to_apple_gateway, service.send(:build_apple_msp_payload, 'test-id'), 'test-id')
```

### Integration Testing

The validation is automatically tested through:
1. **ReplyBox UI**: User creates messages through Chatwoot UI
2. **BOT Templates API**: Programmatic message creation via API
3. **UI Templates**: Template-based message creation

All three pathways go through the same validation checkpoints.

## Benefits

1. **Early Error Detection**: Catches invalid payloads before sending to Apple
2. **Detailed Error Messages**: Provides specific validation errors for debugging
3. **Reduced API Failures**: Prevents 400 errors from Apple MSP
4. **Better Debugging**: Comprehensive payload logging
5. **Data Integrity**: Ensures ISO 8601 dates and base64 images are valid
6. **Cost Savings**: Avoids unnecessary API calls to Apple

## Monitoring

### Success Metrics

Monitor these logs for validation health:
- `[AMB PayloadValidator] ✅ Payload validation passed`
- `[AMB PayloadValidator] Payload summary:`

### Failure Metrics

Monitor these logs for validation issues:
- `[AMB PayloadValidator] Payload validation failed:`
- `[AMB Send] Invalid payload:`

### Recommended Alerts

Set up alerts for:
- High validation failure rate (>5% of messages)
- Specific validation errors (ISO 8601, base64, etc.)
- Payload size issues

## Future Enhancements

Potential improvements:
1. Add validation metrics to monitoring dashboard
2. Create validation failure reports
3. Add more specific error codes for different validation failures
4. Implement validation caching for repeated payloads
5. Add validation performance metrics

## Related Documentation

- `docs/apple-messages/case-normalization-specification.md` - CaseTransformer integration
- `docs/api/BOT_TEMPLATES_API.md` - BOT Templates API documentation
- `app/models/concerns/content_attribute_validator.rb` - Database-level validation
- `AGENTS.md` - Apple Messages for Business development guidelines

## Changelog

### October 27, 2025
- ✅ Created PayloadValidatorService
- ✅ Integrated validation into SendMessageService
- ✅ Integrated validation into FormService
- ✅ Integrated validation into CustomExtensionService
- ✅ Added ISO 8601 date validation
- ✅ Added base64 image validation
- ✅ Added payload summary logging
- ✅ RuboCop formatting applied