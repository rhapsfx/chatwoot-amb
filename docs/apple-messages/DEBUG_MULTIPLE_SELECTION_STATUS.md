# List Picker Multiple Selection Debug - Current Status

## Issue
When "Allow multiple selections in this section" checkbox is checked in AMB list picker, the value becomes `false` instead of `true` in the final payload sent to Apple MSP.

## Root Cause Investigation

### What We've Proven ✅

1. **CaseTransformer Works Correctly** (proven by test script)
   - Input: `{"sections": [{"multipleSelection": true}]}` (camelCase)
   - Output: `{"sections": [{"multiple_selection": true}]}` (snake_case)
   - Reverse transformation also works correctly

2. **Service Logic is Correct**
   - Uses `fetch('multiple_selection', false)` which correctly preserves boolean values
   - No longer uses `||` operator that would treat false as falsy

3. **Frontend Says It Converts to Snake Case**
   - Logs show: `{title: "Options", multiple_selection: true}`
   - But backend receives camelCase (see below)

### What the Logs Show ❌

**Frontend Log:**
```javascript
[DEBUG] Converted section: {title: "Options", multiple_selection: true, reason: "explicitly true"}
```

**Backend Receives (from service logs):**
```ruby
[AMB ListPicker] 🚀 RAW sections: [{"title"=>"Options", "multipleSelection"=>true}]
[AMB ListPicker] 🚀 First section multiple_selection: nil
```

**The Problem:**
- Service expects `section['multiple_selection']` (snake_case)
- But receives `section['multipleSelection']` (camelCase)
- Since key doesn't exist, `fetch` returns default `false`

## Hypothesis

The controller's `normalize_apple_messages_content_attributes` before_action is supposed to convert camelCase → snake_case, but it's either:

1. Not being called
2. Not recursively transforming nested sections array
3. Being called but the transformation is being lost before it reaches the service

## New Comprehensive Logging

Added detailed logging at three points:

### 1. Controller Normalization (BEFORE)
```ruby
[API] 🔍 BEFORE normalization:
[API] 🔍   Section keys: [...]
[API] 🔍   multipleSelection (string): true
[API] 🔍   multiple_selection (string): nil
```

### 2. Controller Normalization (AFTER)
```ruby
[API] 🔍 AFTER normalization:
[API] 🔍   Section keys: [...]
[API] 🔍   multipleSelection (string): nil
[API] 🔍   multiple_selection (string): true  <- Should be this!
```

### 3. create_params Method (AFTER normalization should be applied)
```ruby
[API] 🔥 create_params called AFTER normalization
[API] 🔥   Raw params section keys: [...]
[API] 🔥   multipleSelection: nil
[API] 🔥   multiple_selection: true  <- Should be this!
```

## Next Test

Run the list picker test with "Allow multiple selections" checkbox checked.

### Expected Results (if normalization works):

```
[API] 🔍 BEFORE - multipleSelection: true, multiple_selection: nil
[API] 🔍 AFTER - multipleSelection: nil, multiple_selection: true
[API] 🔥 create_params - multipleSelection: nil, multiple_selection: true
[AMB ListPicker] 🚀 First section multiple_selection: true
```

### If normalization FAILS:

```
[API] 🔍 BEFORE - multipleSelection: true, multiple_selection: nil
[API] 🔍 AFTER - multipleSelection: true, multiple_selection: nil  <- STILL camelCase!
[API] 🔥 create_params - multipleSelection: true, multiple_selection: nil
[AMB ListPicker] 🚀 First section multiple_selection: nil
```

## Files Modified

1. `/Users/rhaps/LocalGit/chatwoot/app/controllers/api/v1/accounts/conversations/messages_controller.rb`
   - Lines 283-320: Enhanced BEFORE/AFTER normalization logging
   - Lines 181-193: Added create_params logging

2. `/Users/rhaps/LocalGit/chatwoot/script/test_case_transformer_sections.rb`
   - Standalone test proving CaseTransformer works correctly

## Test Scripts

### 1. Test CaseTransformer (proven to work ✅)
```bash
rails runner script/test_case_transformer_sections.rb
```

### 2. Test List Picker (next step)
1. Open Chatwoot AMB conversation
2. Click "Send List Picker"
3. Check "Allow multiple selections in this section"
4. Add some options
5. Send message
6. Check logs for the 🔍 and 🔥 markers

## Files to Check After Test

```bash
tail -f log/development.log | grep -E "(🔍|🔥|🚀|AMB)"
```

Look for:
- `[API] 🔍` - Controller normalization logs
- `[API] 🔥` - create_params logs
- `[AMB ListPicker] 🚀` - Service input logs
- `[AMB Send] 🟢` - Service output logs
