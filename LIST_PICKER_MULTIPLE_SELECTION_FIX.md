# List Picker Multiple Selection Checkbox Fix

## Issue

When editing a list picker template, checking "Allow multiple selections in this section" checkbox did not persist the `multipleSelection: true` value. The checkbox always appeared unchecked when reopening the template editor, and the Apple MSP payload showed `multipleSelection: false`.

## Root Cause

The `ListPickerBlockEditor.vue` component's `normalizeSections` function was only checking for `section.multiple_selection` (snake_case) when loading template data:

```javascript
multipleSelection: section.multiple_selection ?? false
```

However, templates store properties with camelCase keys (`multipleSelection`), so the function couldn't find the value and defaulted to `false`.

## Solution

Updated `/Users/rhaps/LocalGit/chatwoot/app/javascript/dashboard/routes/dashboard/settings/templates/components/blocks/ListPickerBlockEditor.vue`:

### Before
```javascript
const normalizeSections = sections => {
  if (\!sections || \!Array.isArray(sections)) return [];

  return sections.map(section => ({
    title: section.title || 'Options',
    multipleSelection: section.multiple_selection ?? false,
    // ...
  }));
};
```

### After
```javascript
const normalizeSections = sections => {
  if (\!sections || \!Array.isArray(sections)) return [];

  return sections.map(section => ({
    title: section.title || 'Options',
    // Handle both camelCase (from template) and snake_case (from API)
    multipleSelection: section.multipleSelection ?? section.multiple_selection ?? false,
    items: (section.items || []).map(item => ({
      title: item.title || '',
      subtitle: item.subtitle || '',
      identifier: item.identifier || '',
      order: item.order ?? 0,
      // Handle both camelCase and snake_case for image_identifier
      image_identifier: item.image_identifier || item.imageIdentifier || '',
    })),
  }));
};
```

## Data Flow

1. **Template Creation/Edit**:
   - User checks "Allow multiple selections" checkbox
   - `ListPickerBlockEditor` stores: `{ multipleSelection: true }`
   - Template saved to DB with camelCase: `{ multipleSelection: true }`

2. **Template Loading**:
   - Template loads from API with: `{ multipleSelection: true }`
   - `normalizeSections` checks: `section.multipleSelection ?? section.multiple_selection`
   - Finds `multipleSelection: true`
   - Checkbox renders as checked ✅

3. **Message Sending via Composer**:
   - Composer converts to snake_case: `{ multiple_selection: true }`
   - API normalizes (already snake_case): `{ multiple_selection: true }`
   - `SendListPickerService` reads: `section['multiple_selection']` = `true`
   - Apple MSP receives: `{ sections: [{ multipleSelection: true }] }` ✅

## Backward Compatibility

The fix maintains backward compatibility by checking both naming conventions:
- Existing templates with `multipleSelection` (camelCase) → Works
- Future API-normalized data with `multiple_selection` (snake_case) → Works
- Missing field → Defaults to `false`

## Testing

**Manual Test Steps**:
1. Open template editor for list picker template
2. Check "Allow multiple selections in this section"
3. Save template
4. Close and reopen template editor
5. Verify checkbox is still checked ✅
6. Send message via composer
7. Verify Apple MSP payload shows `multipleSelection: true` ✅

## Related Files

- `/Users/rhaps/LocalGit/chatwoot/app/javascript/dashboard/routes/dashboard/settings/templates/components/blocks/ListPickerBlockEditor.vue` (Fixed)
- `/Users/rhaps/LocalGit/chatwoot/app/javascript/dashboard/components/widgets/conversation/ReplyBox/AppleMessagesComposer.vue` (Already handles both cases)
- `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/send_list_picker_service.rb` (No changes needed)
- `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/case_transformer.rb` (Has correct mapping)
