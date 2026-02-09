# ImageFetchService Implementation - Complete

**Status**: ✅ Implemented and Tested
**Date**: 2025-01-19
**Location**: `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/image_fetch_service.rb`

## Overview

Created the `AppleMessagesForBusiness::ImageFetchService` that implements a three-tier image fallback hierarchy for Apple Messages for Business features. This service is part of Phase 1 of the long-term image architecture plan.

## Implementation Details

### Service Structure

**Class**: `AppleMessagesForBusiness::ImageFetchService`

**Initialization Parameters**:
- `account_id:` - The account ID for image lookup
- `inbox_id:` - The inbox ID for inbox-specific images
- `embedded_images:` - Array of embedded images (optional, default: [])

**Public Method**:
- `fetch_and_encode(identifiers)` - Returns array of image hashes with base64-encoded data

### Three-Tier Fallback Hierarchy

The service implements the following priority system when looking up images:

#### Tier 1: Inbox-Specific Images (Highest Priority)
- Model: `AppleListPickerImage`
- Scope: `inbox_id` + `identifier`
- Use case: Inbox-specific customizations or overrides
- Logging: `"[ImageFetch] ✅ Found in inbox #{inbox_id}: #{identifier}"`

#### Tier 2: Shared Account-Wide Images
- Model: `SharedAppleImage`
- Scope: `account_id` + `identifier`
- Use case: System images (messages_png, etc.), branding images
- Logging: `"[ImageFetch] ✅ Found in shared (#{image_type}): #{identifier}"`

#### Tier 3: Embedded Images (Fallback)
- Source: `content_attributes['images']`
- Scope: Template-specific base64 images
- Use case: Template-embedded images
- Logging: `"[ImageFetch] ✅ Found in embedded: #{identifier}"`

### Return Format

Each successful image fetch returns:
```ruby
{
  identifier: 'image_id',
  data: 'base64_encoded_string',
  description: 'Image description',
  source: 'inbox' | 'shared_system' | 'shared_branding' | 'shared_template' | 'embedded'
}
```

### Error Handling

- All three fetch methods have `rescue StandardError` blocks
- Errors are logged with `Rails.logger.error`
- Returns `nil` on error (graceful degradation)
- Missing images logged with `Rails.logger.warn`

### Performance Optimizations

**Eager Loading**:
```ruby
.includes(image_attachment: :blob)
```
Prevents N+1 queries when fetching multiple images.

**Early Returns**:
- Returns `[]` immediately if `identifiers.blank?`
- Returns at each tier if image found (avoids unnecessary lookups)

## Code Quality

### RuboCop Compliance

✅ **All checks passed**:
```bash
bundle exec rubocop app/services/apple_messages_for_business/image_fetch_service.rb
# => 1 file inspected, no offenses detected
```

### Rails Loading Test

✅ **Service loads correctly**:
```bash
rails runner "puts AppleMessagesForBusiness::ImageFetchService.new(account_id: 1, inbox_id: 1).class.name"
# => AppleMessagesForBusiness::ImageFetchService
```

### Method Visibility

✅ **Correct visibility**:
- Public: `fetch_and_encode`
- Private: `fetch_single_image`, `fetch_from_inbox`, `fetch_from_shared`, `fetch_from_embedded`

## Testing Results

### Basic Functionality Tests

All tests passed:

**Test 1: Empty identifiers**
- Input: `[]`
- Expected: `[]`
- Result: ✅ PASS

**Test 2: Non-existent image**
- Input: `['non_existent_image']`
- Expected: `[]` (with warning log)
- Result: ✅ PASS

**Test 3: Embedded image fallback**
- Input: `['test_embedded']` (with embedded_images array)
- Expected: `[{identifier: 'test_embedded', source: 'embedded', ...}]`
- Result: ✅ PASS

## Logging Examples

The service provides comprehensive logging:

```
[ImageFetch] Looking for 3 images
[ImageFetch] Account: 1, Inbox: 5
[ImageFetch] ✅ Found in inbox 5: guitar_hero_1
[ImageFetch] ✅ Found in shared (system): messages_png
[ImageFetch] ✅ Found in embedded: custom_icon
[ImageFetch] Found 3/3 images
```

Error logging:
```
[ImageFetch] Error fetching inbox image img_123: Connection timeout
[ImageFetch] ⚠️  Image not found: missing_image
```

## Integration Points

### Ready for Integration

This service is ready to be integrated into existing Apple Messages services:

**Target Services**:
1. `AppleMessagesForBusiness::SendListPickerService`
2. `AppleMessagesForBusiness::SendTimePickerService`
3. `AppleMessagesForBusiness::FormService`
4. `AppleMessagesForBusiness::AcousticHouseBotService`

**Integration Pattern**:
```ruby
def fetch_and_encode_images(identifiers)
  return [] if identifiers.empty?

  AppleMessagesForBusiness::ImageFetchService.new(
    account_id: message.account_id,
    inbox_id: message.inbox_id,
    embedded_images: content_attributes['images']
  ).fetch_and_encode(identifiers)
end
```

## Next Steps (Phase 2)

1. **Create SharedAppleImage model** (with migration)
2. **Update AppleListPickerImage** (add `shared_override` column)
3. **Integrate ImageFetchService** into existing send services
4. **Write RSpec tests** for the service
5. **Run migration scripts** to populate SharedAppleImage

## Design Decisions

### Why Three Tiers?

1. **Tier 1 (Inbox)**: Allows inbox-specific customizations
2. **Tier 2 (Shared)**: Eliminates duplicate system images across inboxes
3. **Tier 3 (Embedded)**: Backward compatibility with existing templates

### Why This Order?

Priority ensures:
- Customizations always win (inbox-specific override)
- Shared resources reduce duplication (account-wide)
- Legacy support maintained (embedded fallback)

### Why Separate Methods?

- **Testability**: Each tier can be tested independently
- **Maintainability**: Clear separation of concerns
- **Extensibility**: Easy to add new tiers or modify existing ones

## Dependencies

**Rails Models** (will be created in Phase 2):
- `SharedAppleImage` - Not yet implemented (Tier 2 will gracefully fail until model exists)

**Existing Models**:
- `AppleListPickerImage` - Already exists

**Ruby Standard Library**:
- `Base64` - For encoding image data

## Compatibility

- **Backward Compatible**: Works with current system (Tier 1 + Tier 3)
- **Forward Compatible**: Ready for SharedAppleImage model (Tier 2)
- **Graceful Degradation**: Each tier fails gracefully if unavailable

## File Information

**File Path**: `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/image_fetch_service.rb`
**Lines of Code**: 105 lines
**Module/Class Style**: Compact (uses `::` notation per RuboCop)
**Encoding**: UTF-8 with frozen string literal

---

**Implementation Complete**: Ready for Phase 2 integration and testing.
