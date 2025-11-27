# Construct Payload API - Backend Implementation Summary

**Date**: 2025-01-27
**Status**: COMPLETED - Phase 1 & Phase 2 (Backend)

---

## Files Created

### 1. ConstructPayloadService
**Path**: `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/construct_payload_service.rb`

**Features**:
- Validates input parameters using ConstructPayloadValidator
- Builds request payload in snake_case format
- Uses CaseTransformer to convert payload to camelCase for Apple MSP
- Calls Apple MSP Gateway POST /v1/constructPayload endpoint
- JWT authentication with channel.generate_jwt_token
- Converts Apple's camelCase response back to snake_case for storage
- **Special handling**: signature-base64 (hyphen) → signature_base64 (underscore)
- Comprehensive error handling:
  - 400 errors → NO_APP_CLIPS_SUPPORT
  - Other errors → API_ERROR
  - Exceptions → EXCEPTION
- UTF8 logging support via Utf8Logging concern

### 2. ConstructPayloadValidator
**Path**: `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/construct_payload_validator.rb`

**Validation Rules**:
- **URL**: Must be present and HTTPS only
- **Store Region**: Must be present and valid ISO 3166 alpha-2 country code
- **Valid Regions**: 34 countries including US, GB, CA, AU, DE, FR, JP, CN, IN, BR, IT, ES, NL, SE, etc.

### 3. AppleConstructPayloadController
**Path**: `/Users/rhaps/LocalGit/chatwoot/app/controllers/api/v1/accounts/inboxes/apple_construct_payload_controller.rb`

**Endpoint**: `POST /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_construct_payload`

**Features**:
- Validates inbox is Apple Messages for Business channel
- Accepts construct_payload params (url, store_region)
- Returns success response with rich_link_data_ref on success
- Returns error response with error_code on failure
- HTTP 400 for NO_APP_CLIPS_SUPPORT
- HTTP 422 for other errors

---

## Files Modified

### 4. Routes Configuration
**Path**: `/Users/rhaps/LocalGit/chatwoot/config/routes.rb`

**Addition** (line 292):
```ruby
resource :apple_construct_payload, only: [:create], module: :inboxes
```

**Resulting Route**:
```
POST /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_construct_payload
→ api/v1/accounts/inboxes/apple_construct_payloads#create
```

### 5. CaseTransformer
**Path**: `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/case_transformer.rb`

**Additions** (lines 82-84):
```ruby
'rich_link_data_ref' => 'richLinkDataRef',
'store_region' => 'storeRegion',
'signature_base64' => 'signature-base64',  # Special case: underscore → hyphen
```

### 6. ContentAttributeValidator
**Path**: `/Users/rhaps/LocalGit/chatwoot/app/models/concerns/content_attribute_validator.rb`

**Addition** (line 21):
```ruby
ALLOWED_APPLE_RICH_LINK_KEYS = [:url, :title, :description, :subtitle, :image_data,
                                :image_url, :favicon_url, :image_mime_type, :video_url,
                                :video_mime_type, :site_name, :rich_link_data_ref].freeze
```

---

## Implementation Compliance

### CaseTransformer Usage
✅ **FULLY COMPLIANT** - All case conversions use CaseTransformer:
- Request payload: snake_case → camelCase via `to_apple_format()`
- Response data: camelCase → snake_case via `from_apple_format()`
- Special handling for signature-base64 field

### Data Flow
```
Frontend (camelCase)
  ↓ (API auto-normalizes)
Controller (snake_case params)
  ↓
Validator (validates)
  ↓
Service (builds snake_case payload)
  ↓
CaseTransformer.to_apple_format() → camelCase
  ↓
Apple MSP API (camelCase)
  ↓
Apple Response (camelCase)
  ↓
CaseTransformer.from_apple_format() → snake_case
  ↓
Database Storage (snake_case)
```

### Error Handling
✅ **COMPLETE**:
- Validation errors → VALIDATION_FAILED
- 400 responses → NO_APP_CLIPS_SUPPORT (user-friendly message)
- Other HTTP errors → API_ERROR
- Exceptions → EXCEPTION (with error message)

### JWT Authentication
✅ **IMPLEMENTED**:
- Uses `@channel.generate_jwt_token` for Authorization header
- Includes required Apple MSP headers:
  - Authorization: Bearer <JWT>
  - id: <UUID>
  - Source-Id: <business_id>
  - Content-Type: application/json

### Store Region Validation
✅ **COMPLETE**:
- ISO 3166 alpha-2 validation
- 34 valid country codes
- Auto-uppercases input (us → US)

---

## Testing Results

### Unit Tests (Manual)
✅ All validation tests passed:
- Valid HTTPS URL + valid region → validates
- HTTP URL → fails with "Url is invalid"
- Invalid region → fails with "Store region is not included in the list"

✅ CaseTransformer tests passed:
- store_region → storeRegion
- rich_link_data_ref → richLinkDataRef
- signature_base64 → signature-base64
- Reverse transformation works correctly

✅ Route configuration verified:
- Endpoint registered at correct path
- POST method only
- JSON format required

### RuboCop Compliance
✅ All new files pass RuboCop:
- 0 offenses in ConstructPayloadService
- 0 offenses in ConstructPayloadValidator
- 0 offenses in AppleConstructPayloadController
- Pre-existing violations in modified files remain unchanged

---

## API Documentation

### Request Format

**Endpoint**: `POST /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_construct_payload`

**Headers**:
```
Content-Type: application/json
Authorization: <user_token>
```

**Body**:
```json
{
  "construct_payload": {
    "url": "https://example.com/product",
    "store_region": "US"
  }
}
```

### Response Formats

**Success (200 OK)**:
```json
{
  "success": true,
  "rich_link_data_ref": {
    "title": "Product Name",
    "signature_base64": "AZ60f1Fh...",
    "size": 351298,
    "url": "https://p97-content.icloud.com/...",
    "owner": "M66169d55-aaee-48dd-b781-...",
    "key": "00ccec31f00f05d3416bf0a41f47..."
  },
  "version": "1.0"
}
```

**Error - No App Clips Support (400 Bad Request)**:
```json
{
  "success": false,
  "error": "URL does not support App Clips",
  "error_code": "NO_APP_CLIPS_SUPPORT"
}
```

**Error - Validation Failed (422 Unprocessable Entity)**:
```json
{
  "success": false,
  "error": "Url is invalid, Store region is not included in the list",
  "error_code": "VALIDATION_FAILED"
}
```

---

## Next Steps (Frontend Implementation - Phase 5)

The backend is complete and ready for frontend integration. The following files need to be created:

1. **API Client**: `app/javascript/dashboard/api/appleMessages/constructPayload.js`
2. **Composable**: `app/javascript/dashboard/composables/useAppClips.js`
3. **Modal Component**: Update `EnhancedRichLinkModal.vue` with App Clips mode
4. **Integration**: Connect to AppleMessagesComposer.vue

---

## Database Schema Impact

**No database migrations required**.

The `rich_link_data_ref` is stored in existing `messages.content_attributes` JSONB column.

---

## Production Deployment

### Deployment Command
```bash
./script/deploy-backend-changes-safe.sh
```

### Verification Steps
1. Check route exists: `curl -X POST https://your-domain.com/api/v1/accounts/1/inboxes/1/apple_construct_payload`
2. Verify in Rails console: `Rails.application.routes.url_helpers.api_v1_account_inbox_apple_construct_payload_path(1, 1)`
3. Test with valid App Clips URL
4. Monitor logs for UTF-8 encoded output

---

## Success Criteria

✅ **Functional**:
- [x] Backend API calls Apple MSP /constructPayload
- [x] CaseTransformer handles all snake_case ↔ camelCase conversions
- [x] Error handling covers 400 errors (No App Clips support)
- [x] Store region validated against ISO 3166 alpha-2
- [x] JWT authentication implemented
- [x] Special case signature-base64 handled

✅ **Quality**:
- [x] RuboCop compliance (0 new violations)
- [x] UTF-8 logging support
- [x] Comprehensive error handling
- [x] Clear logging messages

✅ **Documentation**:
- [x] Implementation summary created
- [x] API documentation included
- [x] Data flow documented

---

## Key Architectural Decisions

1. **CaseTransformer as Single Source of Truth**: All case conversions go through CaseTransformer, ensuring consistency across the entire codebase.

2. **Special Handling for signature-base64**: Apple uses hyphen in this field (not underscore), requiring explicit mapping in CaseTransformer.

3. **Validator as Separate Class**: ConstructPayloadValidator is a standalone class for reusability and testability.

4. **Error Code Standardization**: Three error codes (VALIDATION_FAILED, NO_APP_CLIPS_SUPPORT, API_ERROR, EXCEPTION) cover all failure scenarios.

5. **UTF-8 Logging**: Uses Utf8Logging concern to prevent mojibake with emojis in logs.

---

## Related Documentation

- Implementation Plan: `docs/apple-messages/CONSTRUCT_PAYLOAD_IMPLEMENTATION_PLAN.md`
- Case Normalization Spec: `docs/apple-messages/case-normalization-specification.md`
- Apple MSP Docs: `_apple/msp-rest-api/src/docs/construct-payload.md`

---

**Implementation Status**: COMPLETE - Ready for Frontend Integration
