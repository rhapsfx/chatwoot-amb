# UTF-8 Logging Fix for FlowExecutor and SendMessageService

## Problem
Emoji characters in log messages were appearing as garbled text (mojibake) like:
- `âœ…` instead of ✅
- `â�±ï¸�` instead of ⏱️
- `ðŸ"‹` instead of 📋

## Root Cause
The logging methods in `FlowExecutorService` and some calls in `SendMessageService` were not encoding strings to UTF-8 before writing to logs, causing incorrect byte representation of multi-byte UTF-8 characters.

## Solution Applied

### 1. FlowExecutorService
**File**: `app/services/apple_messages_for_business/flow_executor_service.rb`

Added UTF-8 logging support:
```ruby
class AppleMessagesForBusiness::FlowExecutorService
  include AppleMessagesForBusiness::Concerns::Utf8Logging
  # ... rest of class
end
```

Removed basic logging methods that didn't handle UTF-8 encoding.

### 2. SendMessageService  
**File**: `app/services/apple_messages_for_business/send_message_service.rb`

Updated critical log statements to use UTF-8 safe methods:
- Changed `Rails.logger.info` → `log_info`
- Changed `Rails.logger.warn` → `log_warn`
- Changed `Rails.logger.error` → `log_error`

### 3. VSCode Settings
**File**: `.vscode/settings.json`

Configured VSCode to always use UTF-8 encoding for log files:
```json
{
  "files.encoding": "utf8",
  "files.autoGuessEncoding": false,
  "[log]": {
    "files.encoding": "utf8"
  }
}
```

## How the Fix Works

The `Utf8Logging` concern provides a `utf8_encode` method that:
1. Converts strings to UTF-8 encoding with proper handling of invalid characters
2. Recursively processes hashes and arrays
3. Wraps all logging methods to automatically encode output

## Verification Steps

### 1. Check Log File Encoding
```bash
file -b --mime-encoding log/development.log
# Should output: utf-8
```

### 2. View Logs in Terminal
```bash
tail -50 log/development.log | grep "FlowExecutor\|Apple MSP"
```

You should see properly rendered emojis like:
```
[FlowExecutor] 🚀 Executing flow 'Acoustic House Flow'
[FlowExecutor] ✅ Template executed: welcome_text_1
[FlowExecutor] ⏱️  Waiting between templates
✅ Apple MSP - Stored payload (status: sent, type: text)
```

### 3. View in VSCode
After the fix:
1. Close and reopen the log file in VSCode
2. OR click the encoding indicator in bottom-right corner
3. Select "Reopen with Encoding" → "UTF-8"

The emojis should now display correctly in VSCode.

## Testing
Trigger a flow execution to generate new log entries:
1. Send a message to the bot (e.g., "restart")
2. Check `log/development.log` for the latest entries
3. Verify emojis display correctly

## Files Modified
1. `app/services/apple_messages_for_business/flow_executor_service.rb`
2. `app/services/apple_messages_for_business/send_message_service.rb`
3. `.vscode/settings.json`

## Files Created
1. `script/test_utf8_logging_fix.rb` - Test script for UTF-8 logging
2. `docs/UTF8_LOGGING_FIX.md` - This documentation

## Notes
- The log file itself is correctly UTF-8 encoded
- Garbled characters only appear when viewing with non-UTF-8 tools
- Terminal/VSCode display issues are configuration problems, not code issues
- The `Utf8Logging` concern is already used by `AcousticHouseBotService` and other services