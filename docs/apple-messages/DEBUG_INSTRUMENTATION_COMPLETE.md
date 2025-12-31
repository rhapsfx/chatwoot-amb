# Multiple Selection Debug - Complete Instrumentation Summary

## Current Status

We have proven that:
1. ✅ **CaseTransformer works correctly** - transforms `multipleSelection` → `multiple_selection`
2. ✅ **Strong params sees normalization** - modifications in before_action are preserved through permit

## Complete Logging Chain

### Stage 1: Controller Normalization (before_action)

**File**: `app/controllers/api/v1/accounts/conversations/messages_controller.rb`
**Lines**: 283-320

**Logs**:
```
[API] 🔍 BEFORE normalization:
[API] 🔍   Section class: ActionController::Parameters
[API] 🔍   Section keys: ["title", "multipleSelection", "items"]
[API] 🔍   multipleSelection (string): true
[API] 🔍   multiple_selection (string): nil

[API] 🔍 Calling from_apple_format with hash class: Hash
[API] 🔍 First section BEFORE transform: {"title"=>"Options", "multipleSelection"=>true}
[API] 🔍 from_apple_format returned class: Hash

[API] 🔍 AFTER normalization:
[API] 🔍   Section keys: ["title", "multiple_selection", "items"]
[API] 🔍   multipleSelection (string): nil
[API] 🔍   multiple_selection (string): true
```

### Stage 2: Strong Params Filtering (create_params)

**File**: `app/controllers/api/v1/accounts/conversations/messages_controller.rb`
**Lines**: 181-193

**Logs**:
```
[API] 🔥 create_params called AFTER normalization
[API] 🔥   Raw params section keys: ["title", "multiple_selection"]
[API] 🔥   multipleSelection: nil
[API] 🔥   multiple_selection: true
```

### Stage 3: MessageBuilder Receipt

**File**: `app/builders/messages/message_builder.rb`
**Lines**: 59-73

**Logs**:
```
[MessageBuilder] 🔥 content_attributes method called
[MessageBuilder] 🔥   @params class: ActionController::Parameters
[MessageBuilder] 🔥   First section keys (BEFORE convert_to_hash): ["title", "multiple_selection"]
[MessageBuilder] 🔥   multipleSelection: nil
[MessageBuilder] 🔥   multiple_selection: true
```

### Stage 4: Service Receipt

**File**: `app/services/apple_messages_for_business/send_list_picker_service.rb`
**Lines**: 239-245

**Logs**:
```
[AMB ListPicker] 🚀 BUILD_LIST_PICKER_DATA CALLED IN CHILD CLASS
[AMB ListPicker] 🚀 RAW sections from content_attributes: [{"title"=>"Options", "multiple_selection"=>true}]
[AMB ListPicker] 🚀 First section multiple_selection: true
```

## Expected Success Flow

If everything works correctly:

```
[API] 🔍 BEFORE - multipleSelection: true, multiple_selection: nil
[API] 🔍 AFTER - multipleSelection: nil, multiple_selection: true
[API] 🔥 create_params - multiple_selection: true
[MessageBuilder] 🔥 - multiple_selection: true
[AMB ListPicker] 🚀 - multiple_selection: true
[AMB ListPicker] 🔍 Section 0 - AFTER merge: multiple_selection = true
[AMB Send] 🟢 multipleSelection (symbol): true
```

Final Apple MSP payload:
```json
{
  "interactiveData": {
    "data": {
      "listPicker": {
        "sections": [
          {
            "title": "Options",
            "multipleSelection": true  ✅
          }
        ]
      }
    }
  }
}
```

## If Normalization Fails

If the before_action normalization doesn't work:

```
[API] 🔍 BEFORE - multipleSelection: true
[API] 🔍 AFTER - multipleSelection: true  ❌ STILL camelCase
[API] 🔥 create_params - multipleSelection: true
[MessageBuilder] 🔥 - multipleSelection: true
[AMB ListPicker] 🚀 - multipleSelection: true (but code checks for multiple_selection)
[AMB ListPicker] 🔍 Section 0 - BEFORE: multiple_selection = nil
[AMB ListPicker] 🔍 Section 0 - AFTER merge: multiple_selection = false  ❌ DEFAULT VALUE
```

## How to Test

1. **Restart server** to load new logging:
   ```bash
   pkill -9 -f 'rails server'
   pkill -9 -f puma
   ./script/dev-server.sh start
   ```

2. **Open log stream**:
   ```bash
   tail -f log/development.log | grep -E "(🔍|🔥|🚀|🟢)"
   ```

3. **Send test list picker**:
   - Open Chatwoot AMB conversation
   - Click "Send List Picker"
   - Check "Allow multiple selections in this section" ✅
   - Add 2-3 options
   - Send message

4. **Analyze logs** to find where transformation fails

## Test Scripts Available

1. **Test CaseTransformer** (proven working ✅):
   ```bash
   rails runner script/test_case_transformer_sections.rb
   ```

2. **Test Strong Params** (proven working ✅):
   ```bash
   rails runner script/test_strong_params_modification.rb
   ```

3. **Test original logic**:
   ```bash
   rails runner script/debug_list_picker_multiselect.rb
   ```

## Files Modified

1. `app/controllers/api/v1/accounts/conversations/messages_controller.rb` (lines 181-193, 283-320)
2. `app/builders/messages/message_builder.rb` (lines 59-73)
3. `app/services/apple_messages_for_business/send_list_picker_service.rb` (lines 239-276)
4. `app/services/apple_messages_for_business/send_message_service.rb` (lines 245-256)

## Documentation

1. `docs/apple-messages/DEBUG_MULTIPLE_SELECTION_STATUS.md` - Initial analysis
2. `script/test_case_transformer_sections.rb` - Proves transformer works
3. `script/test_strong_params_modification.rb` - Proves strong params works
4. `script/debug_list_picker_multiselect.rb` - Original debug script

## Next Steps

The comprehensive logging will reveal:
1. Whether controller normalization is working
2. Whether strong params preserves the normalization
3. Whether MessageBuilder receives correct data
4. Whether the service gets correct data

Once we see the logs, we'll know exactly where to fix the issue.
