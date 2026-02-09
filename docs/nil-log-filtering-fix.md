# Nil Log Filtering Fix

**Date**: November 21, 2025  
**Issue**: Standalone `nil` entries appearing in `log/development.log`  
**Status**: ✅ Fixed

## Problem

The development log was cluttered with standalone `nil` entries like this:

```
Processing by Api::V1::Accounts::NotificationsController#index as JSON
  Parameters: {"page"=>"1", "sort_order"=>"desc", "account_id"=>"1"}
nil
nil
nil
Processing by Api::V1::AccountsController#cache_keys as JSON
```

These `nil` entries were generated when:
1. Code called `Rails.logger.info(nil)` or similar
2. Methods returned `nil` and that value was logged
3. The log sanitizer removed sensitive content but still wrote the log entry

## Root Cause

The `NilFilteringLogDevice` in `config/initializers/active_job_log_sanitizer.rb` was attempting to filter `nil` at the IO device level, but by that point Rails had already formatted the message with timestamps and metadata. The filter only caught raw "nil" strings, not formatted log entries.

## Solution

Modified the `RailsLoggerJobSuppressor` module to catch and filter `nil` values **BEFORE** they reach the logger's formatter:

### Key Changes in `config/initializers/active_job_log_sanitizer.rb`

1. **Early nil detection**: Check for `nil` values at the beginning of `suppress_if_needed()`
2. **Return nil instead of empty string**: When filtering, return `nil` to signal "skip this log entry"
3. **Updated all log methods**: Changed condition from `return if suppressed == ''` to `return if suppressed.nil?`

```ruby
def suppress_if_needed(message)
  # CRITICAL: Filter out nil values BEFORE they get formatted
  # This prevents "nil" from appearing in logs
  return nil if message.nil?
  
  return message unless message.is_a?(String)

  # Filter out "nil" lines completely (from puts statements or return values)
  return nil if message.strip == 'nil' || message == 'nil'
  
  # ... rest of filtering logic
end
```

## How It Works

### Before the Fix
```
Code: Rails.logger.info(nil)
  ↓
Logger formatter: "2025-11-21 07:45:45 +0100 nil"
  ↓
NilFilteringLogDevice: Tries to filter "nil" but sees formatted string
  ↓
Log file: "nil" appears in log
```

### After the Fix
```
Code: Rails.logger.info(nil)
  ↓
RailsLoggerJobSuppressor.suppress_if_needed(nil)
  ↓
Returns: nil (signals skip)
  ↓
Log method: return if suppressed.nil?
  ↓
Log file: Nothing written ✓
```

## Testing

Run the test script to verify the fix:

```bash
bundle exec ruby script/test_nil_log_filtering.rb
```

Expected results:
- ✅ `Rails.logger.info(nil)` - No log entry
- ✅ `Rails.logger.info("nil")` - No log entry  
- ✅ `Rails.logger.info { nil }` - No log entry
- ✅ `Rails.logger.info("Normal message")` - Logged normally
- ✅ `Rails.logger.info("Value is nil")` - Logged normally (contains "nil" but isn't just "nil")

## Benefits

1. **Cleaner logs**: No more standalone `nil` entries cluttering the log file
2. **Better readability**: Easier to find actual log messages
3. **Reduced noise**: Log files are smaller and more focused
4. **Maintains security**: Still filters sensitive content, just doesn't write empty entries

## Files Modified

- `config/initializers/active_job_log_sanitizer.rb` - Updated `RailsLoggerJobSuppressor` module
- `script/test_nil_log_filtering.rb` - Created test script

## Related Issues

This fix complements the existing log sanitization features:
- Job argument suppression for `ActionCableBroadcastJob` and `EventDispatcherJob`
- Base64 data truncation in `ContentAttributeValidator` logs
- Sensitive parameter filtering via Rails parameter filtering

## Notes

- The `NilFilteringLogDevice` is still in place as a backup filter at the IO level
- This fix works for all log levels: debug, info, warn, error, fatal, unknown
- The fix preserves the ability to log messages that contain the word "nil" (e.g., "Value is nil")