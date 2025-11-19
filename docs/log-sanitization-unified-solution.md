# Log Sanitization: Unified Solution

## Problem Solved

Development logs were bloated with 300KB+ log entries from high-frequency jobs:
- `ActionCableBroadcastJob`
- `EventDispatcherJob`

Both "Enqueued" and "Performing" logs contained massive base64-encoded payloads.

## Root Cause Discovery

After 8 different approaches, we discovered TWO core issues:

1. **Sidekiq was logging to `$stdout`, bypassing Rails.logger entirely**
2. **Initialization order**: Sidekiq captured Rails.logger reference BEFORE it was wrapped

The log flow was:
```
Sidekiq → Unwrapped Rails.logger (captured early) → $stdout → log/development.log
                                                                (bypasses wrapper!)
```

## Final Solution: Single Wrapper with Correct Initialization Order

**Key insight**: Wrap Rails.logger FIRST, THEN update Sidekiq's logger reference

```
┌─────────────────────────────────────────────────────────┐
│ 1. Wrap Rails.logger with SanitizingLoggerProxy        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Update Sidekiq.logger = Rails.logger (wrapped!)     │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ Sidekiq logs → Wrapped Rails.logger → Sanitization     │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ Original logger → log/development.log (clean!)          │
└─────────────────────────────────────────────────────────┘
```

## Implementation

### Single Initializer: `config/initializers/rails_log_sanitizer.rb`

**Complete solution in one file:**

```ruby
module RailsLogSanitizer
  class SanitizingLoggerProxy
    HIGH_FREQUENCY_JOB_PATTERN = /(Enqueued|Performing).*(ActionCableBroadcastJob|EventDispatcherJob)/
    MAX_LOG_LINE_SIZE = 500

    def initialize(original_logger)
      @original_logger = original_logger
    end

    # Forward all methods to original logger
    def method_missing(method, *args, &block)
      @original_logger.send(method, *args, &block)
    end

    def respond_to_missing?(method, include_private = false)
      @original_logger.respond_to?(method, include_private) || super
    end

    # Override logging methods
    %w[debug info warn error fatal unknown].each do |level|
      define_method(level) do |message = nil, &block|
        sanitized_message = sanitize_if_needed(message || block&.call)
        @original_logger.public_send(level, sanitized_message)
      end
    end

    def add(severity, message = nil, progname = nil)
      if block_given?
        sanitized_message = sanitize_if_needed(yield)
        @original_logger.add(severity, sanitized_message, progname)
      else
        sanitized_message = sanitize_if_needed(message)
        @original_logger.add(severity, sanitized_message, progname)
      end
    end

    def <<(msg)
      @original_logger << sanitize_if_needed(msg)
    end

    private

    def sanitize_if_needed(message)
      return message unless message.is_a?(String)

      if message =~ HIGH_FREQUENCY_JOB_PATTERN
        if message.include?('with arguments:')
          message.split('with arguments:').first + 'with arguments: [SANITIZED]'
        else
          message
        end
      elsif message.length > MAX_LOG_LINE_SIZE
        "#{message[0...MAX_LOG_LINE_SIZE]}... [TRUNCATED - original size: #{message.length} bytes]"
      else
        message
      end
    end
  end
end

# CRITICAL: Order matters!
Rails.application.config.after_initialize do
  unless Rails.logger.is_a?(RailsLogSanitizer::SanitizingLoggerProxy)
    # Step 1: Wrap Rails.logger
    original_logger = Rails.logger
    Rails.logger = RailsLogSanitizer::SanitizingLoggerProxy.new(original_logger)
    Rails.logger.info '[RailsLogger] Log sanitizer installed - oversized logs will be truncated'

    # Step 2: Update Sidekiq to use the WRAPPED logger
    if defined?(Sidekiq)
      Sidekiq.configure_server do |config|
        config.logger = Rails.logger  # ← Now gets wrapped logger
        Rails.logger.info '[RailsLogger] Sidekiq logger updated to use wrapped logger'
      end

      Sidekiq.configure_client do |config|
        config.logger = Rails.logger  # ← For "Enqueued" logs
      end
    end
  end
end
```

## Results

**Before** (300KB+ per line):
```
Enqueued ActionCableBroadcastJob to Sidekiq(critical) with arguments:
["channel_id", "message.updated", {"id"=>123, "content_attributes"=>{"images"=>[{"data"=>"aXaZ...300KB of base64..."}]}}]
```

**After** (~50 bytes per line):
```
Enqueued ActionCableBroadcastJob to Sidekiq(critical) with arguments: [SANITIZED]
```

**Size reduction: 99.98%** 🎉

## Why This Works

1. **Correct initialization order**: Wrap first, THEN update Sidekiq's reference
2. **Single sanitization point**: All logs flow through one wrapped logger
3. **No $stdout bypass**: Sidekiq gets the wrapped logger, not original
4. **Log-level sanitization**: Only intercepts output, jobs execute normally
5. **Fallback protection**: ANY log > 500 chars gets truncated

## Verification

After restarting server, check logs for:
```bash
tail -f log/development.log | grep -E "Sidekiq|RailsLogger"
```

You should see:
```
[RailsLogger] Log sanitizer installed - oversized logs will be truncated
[RailsLogger] Sidekiq logger updated to use wrapped logger
```

Then verify job logs are clean:
```bash
tail -f log/development.log | grep "ActionCableBroadcastJob\|EventDispatcherJob"
```

Should see:
```
Enqueued ActionCableBroadcastJob ... with arguments: [SANITIZED]
Performing ActionCableBroadcastJob ... with arguments: [SANITIZED]
```

## Files Modified

1. ✅ `config/initializers/rails_log_sanitizer.rb` - Complete solution (wrapper + Sidekiq config)
2. ✅ `app/services/log_sanitizer_service.rb` - Core sanitization logic (unchanged)
3. ❌ `config/initializers/sidekiq_log_sanitizer.rb` - **DELETED** (redundant)

## Restart Required

⚠️ **CRITICAL**: Initializer changes only load on server startup

```bash
./script//dev-server.sh restart
```

## Previous Failed Approaches (For Reference)

1. ❌ ActiveJob::Logging patch - Bypassed by Sidekiq's logging
2. ❌ Sidekiq ClientMiddleware - Corrupted job data before enqueueing
3. ❌ Custom Sidekiq logger to $stdout - Logs bypassed Rails.logger
4. ❌ Rails logger wrapper v1 - Pattern didn't match
5. ❌ Rails logger wrapper v2 - Still bypassed by $stdout flow
6. ❌ Sidekiq ServerMiddleware - Broke job execution (mutated job arguments)
7. ❌ Separate sidekiq_log_sanitizer.rb - **Initialization order bug**: Sidekiq captured unwrapped logger
8. ✅ **Final solution** - Single initializer with correct order: wrap FIRST, then update Sidekiq

## Key Insights

**The breakthrough realizations**:
1. Sidekiq logs to `$stdout` by default, bypassing Rails.logger wrapper
2. Setting `Sidekiq.logger = Rails.logger` fixes the routing
3. **BUT** initialization order matters: if Sidekiq captures the logger reference BEFORE wrapping, it keeps the unwrapped version
4. **Solution**: Wrap Rails.logger first, THEN update Sidekiq's logger to use the wrapped version
