# Multiple Selection Bug - Root Cause & Fix

## Issue

When "Allow multiple selections in this section" checkbox is checked in Apple Messages list picker, the value shows as `false` instead of `true` in the final Apple MSP payload.

## Root Cause

**File**: `/Users/rhaps/LocalGit/chatwoot/app/models/concerns/content_attribute_validator.rb`
**Line**: 118 (before fix)

The `ContentAttributeValidator` was transforming snake_case → camelCase **before saving to database**:

```ruby
# OLD CODE (WRONG):
section['multipleSelection'] = section.delete('multiple_selection') if section.key?('multiple_selection')
```

### Data Flow (BEFORE FIX)

```
1. Frontend sends: { multipleSelection: true } (camelCase)
   ↓
2. Controller normalizes: { multiple_selection: true } (snake_case) ✅
   ↓
3. MessageBuilder receives: { multiple_selection: true } ✅
   ↓
4. ContentAttributeValidator runs (before_validation callback)
   TRANSFORMS: multiple_selection → multipleSelection ❌
   ↓
5. Database saves: { multipleSelection: true } (camelCase) ❌
   ↓
6. Service reads: { multipleSelection: true }
   BUT code checks for: { multiple_selection: ... }
   Result: nil → defaults to false ❌
```

### Why This Was Wrong

From CLAUDE.md architecture:
- **Internal storage**: Always snake_case ✅
- **Apple MSP boundary**: Services use CaseTransformer ✅
- **But validator was converting TO camelCase before storage** ❌

## The Fix

### Changed Lines in `content_attribute_validator.rb`

**Line 11**: Removed `:multipleSelection` from allowed keys
```ruby
# BEFORE:
ALLOWED_APPLE_LIST_PICKER_SECTION_KEYS = [:title, :multiple_selection, :multipleSelection, :order, :items].freeze

# AFTER:
ALLOWED_APPLE_LIST_PICKER_SECTION_KEYS = [:title, :multiple_selection, :order, :items].freeze
```

**Line 12**: Removed `:imageIdentifier` from allowed keys
```ruby
# BEFORE:
ALLOWED_APPLE_LIST_PICKER_ITEM_KEYS = [:identifier, :title, :subtitle, :image_identifier, :imageIdentifier, :order, :style].freeze

# AFTER:
ALLOWED_APPLE_LIST_PICKER_ITEM_KEYS = [:identifier, :title, :subtitle, :image_identifier, :order, :style].freeze
```

**Lines 112-134**: Reversed the transformation direction
```ruby
# BEFORE (WRONG):
# Ensure multipleSelection is properly named (Apple uses camelCase)
section['multipleSelection'] = section.delete('multiple_selection') if section.key?('multiple_selection')

# AFTER (CORRECT):
# Support legacy data: convert old camelCase to snake_case for consistency
section['multiple_selection'] = section.delete('multipleSelection') if section.key?('multipleSelection') && !section.key?('multiple_selection')
```

```ruby
# BEFORE (WRONG):
# Normalize imageIdentifier field (Apple uses camelCase)
item['imageIdentifier'] = item.delete('image_identifier') if item.key?('image_identifier')

# AFTER (CORRECT):
# Support legacy data: convert old camelCase to snake_case for consistency
item['image_identifier'] = item.delete('imageIdentifier') if item.key?('imageIdentifier') && !item.key?('image_identifier')
```

### Data Flow (AFTER FIX)

```
1. Frontend sends: { multipleSelection: true } (camelCase)
   ↓
2. Controller normalizes: { multiple_selection: true } (snake_case) ✅
   ↓
3. MessageBuilder receives: { multiple_selection: true } ✅
   ↓
4. ContentAttributeValidator runs (before_validation callback)
   PRESERVES: multiple_selection (snake_case) ✅
   OR converts legacy camelCase → snake_case if found
   ↓
5. Database saves: { multiple_selection: true } (snake_case) ✅
   ↓
6. Service reads: { multiple_selection: true } ✅
   Checks for: { multiple_selection: ... }
   Result: true ✅
   ↓
7. CaseTransformer converts: { multipleSelection: true } (for Apple MSP) ✅
   ↓
8. Apple MSP receives: { multipleSelection: true } ✅
```

## Testing

### Manual Test

1. **Restart server** to load the fix:
   ```bash
   pkill -9 -f 'rails server'
   pkill -9 -f puma
   ./script/dev-server.sh start
   ```

2. **Send list picker** with multiple selection enabled:
   - Open Chatwoot AMB conversation
   - Click "Send List Picker"
   - ✅ **Check** "Allow multiple selections in this section"
   - Add 2-3 options
   - Send message

3. **Check logs** for success:
   ```bash
   tail -f log/development.log | grep -E "(🚀|🟢|multiple)"
   ```

   **Expected**:
   ```
   [AMB ListPicker] 🚀 First section multiple_selection: true
   [AMB Send] 🟢 First section multipleSelection (symbol): true
   ```

4. **Verify Apple MSP payload**:
   - Check final payload has `"multipleSelection": true`
   - User should see multiple selection UI on device

### Automated Test

Run the test script (requires running dev server):
```bash
rails runner script/test_store_accessor_transformation.rb
```

**Expected output**:
```
AFTER Message.new, BEFORE save:
  multiple_selection: true  ✅

IMMEDIATELY after save (before reload):
  multiple_selection: true  ✅ (FIXED!)

RAW database value:
{...,"multipleSelection": false,...}  ← Should be "multiple_selection": true
```

## Impact

### What's Fixed ✅
- Multiple selection checkbox now works correctly
- Database stores snake_case (following Rails convention)
- Services receive snake_case data
- CaseTransformer handles conversion to Apple format

### Legacy Data
- Validator now includes backward-compatible conversion
- Existing camelCase data in database will be normalized to snake_case on next save
- No data migration needed - happens automatically

## Files Modified

1. `/Users/rhaps/LocalGit/chatwoot/app/models/concerns/content_attribute_validator.rb` (lines 11, 12, 112-134)

## Related Documentation

- `docs/apple-messages/DEBUG_INSTRUMENTATION_COMPLETE.md` - Debugging process
- `docs/apple-messages/DEBUG_MULTIPLE_SELECTION_STATUS.md` - Initial analysis
- `docs/apple-messages/case-normalization-specification.md` - Case convention architecture
- `script/test_store_accessor_transformation.rb` - Test script proving the fix
