# Apple Messages for Business - Log Sanitization Complete Guide

**Status**: ✅ **ACTIVE** (Deployed November 2025)
**Last Updated**: November 24, 2025

---

## Table of Contents

1. [Overview](#overview)
2. [Two-Tier Log Sanitization System](#two-tier-log-sanitization-system)
3. [Apple Messages LogSanitizer](#apple-messages-logsanitizer)
4. [Rails Global Log Sanitizer](#rails-global-log-sanitizer)
5. [Usage Patterns](#usage-patterns)
6. [Testing](#testing)
7. [Performance Impact](#performance-impact)
8. [Troubleshooting](#troubleshooting)

---

## Overview

Chatwoot implements a **two-tier log sanitization system** to prevent base64-encoded images and large payloads from bloating development and production logs:

### Problem Statement

Without sanitization:
- **Base64 image in logs**: 15-150KB per image
- **Apple Messages payloads**: Can contain 5-10 images = 75-1500KB per log entry
- **High-frequency jobs**: ActionCableBroadcastJob with images = 300KB+ per line
- **Custom payloads**: User-submitted JSON can be 100KB+

Result: **Log files grow to 100MB+ per hour**, making debugging impossible.

### Solution Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ TIER 1: Apple Messages LogSanitizer                         │
│ - Detects base64 images in Apple Messages payloads          │
│ - Replaces with compact metadata: [BASE64 15.2KB]           │
│ - Supports multiple output formats (compact/preview/detail) │
│ - Preserves non-sensitive data for debugging                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────────┐
│ TIER 2: Rails Global Log Sanitizer (Fallback)              │
│ - Catches any logs > 500 chars from ANY source              │
│ - Sanitizes high-frequency Sidekiq jobs                     │
│ - Truncates oversized logs with size indicator              │
└─────────────────────────────────────────────────────────────┘
```

---

## Apple Messages LogSanitizer

### Purpose

Specialized sanitizer for Apple Messages for Business payloads. Intelligently detects and truncates base64-encoded images while preserving important metadata.

### Location

**Module**: `AppleMessagesForBusiness::LogSanitizer`
**File**: `app/services/apple_messages_for_business/log_sanitizer.rb`

### Features

✅ **Smart Detection**:
- Detects base64 by pattern (200+ chars, base64 alphabet)
- Identifies data URLs: `data:image/png;base64,iVBORw0KGgo...`
- Recognizes image signatures (PNG, JPEG, GIF, WebP, BMP, TIFF, ICO)
- Uses key names to identify data fields (`data`, `image`, `base64`)

✅ **Multiple Output Formats**:
- **Compact** (default): `[BASE64 15.2KB]`
- **Preview**: `[BASE64 15.2KB | Preview: iVBORw0KGgo...]`
- **Detailed**: `[BASE64 15.2KB | PNG image | identifier: logo_png | data URL]`

✅ **Deep Sanitization**:
- Recursively sanitizes nested hashes
- Handles arrays of images
- Preserves non-sensitive data
- Returns deep copy (non-destructive)

✅ **Helper Methods**:
- `contains_base64?(data)` - Check if data has images
- `base64_summary(data)` - Get statistics about images

### Usage Examples

#### Basic Sanitization (Compact Format)

```ruby
# Default: compact format
payload = {
  'title' => 'Browse Products',
  'images' => [
    {
      'identifier' => 'logo_png',
      'data' => 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB...' # 15KB
    }
  ]
}

sanitized = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(payload)
Rails.logger.info "Payload: #{sanitized.to_json}"

# Output:
# {
#   "title": "Browse Products",
#   "images": [
#     {
#       "identifier": "logo_png",
#       "data": "[BASE64 15.2KB]"
#     }
#   ]
# }
```

#### Preview Format (Shows First 20 Chars)

```ruby
sanitized = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(
  payload,
  format: :preview,
  preview_length: 20
)

# Output:
# {
#   "data": "[BASE64 15.2KB | Preview: iVBORw0KGgoAAAANSUhE...]"
# }
```

#### Detailed Format (Maximum Information)

```ruby
sanitized = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(
  payload,
  format: :detailed
)

# Output:
# {
#   "data": "[BASE64 15.2KB | PNG image | identifier: logo_png]"
# }
```

#### Check for Base64 Content

```ruby
if AppleMessagesForBusiness::LogSanitizer.contains_base64?(payload)
  summary = AppleMessagesForBusiness::LogSanitizer.base64_summary(payload)

  Rails.logger.info "Payload contains #{summary[:count]} images"
  Rails.logger.info "Total size: #{summary[:total_kb]}KB"

  summary[:images].each do |img|
    Rails.logger.debug "  - #{img[:format]} image: #{img[:size_kb]}KB, key: #{img[:key]}"
  end
end

# Output:
# Payload contains 3 images
# Total size: 42.5KB
#   - PNG image: 15.2KB, key: data
#   - JPEG image: 18.3KB, key: data
#   - PNG image: 9.0KB, key: data
```

### Integration in Services

LogSanitizer is integrated into all Apple Messages services that handle images:

#### SendCustomPayloadService (Custom Payloads)

```ruby
# app/services/apple_messages_for_business/send_custom_payload_service.rb

def build_interactive_data
  # Parse custom payload
  custom_data = parse_custom_payload(custom_payload_json, skip_validation)

  # Log payload analysis with base64 detection
  log_payload_analysis(custom_data)

  # Log sanitized version at debug level
  log_sanitized_payload(custom_data)

  custom_data
end

private

def log_payload_analysis(data)
  if LogSanitizer.contains_base64?(data)
    summary = LogSanitizer.base64_summary(data)
    Rails.logger.info "[CustomPayload] Payload contains #{summary[:count]} base64 image(s), total size: #{summary[:total_kb]}KB"

    summary[:images].each_with_index do |img, idx|
      Rails.logger.debug "[CustomPayload]   Image #{idx + 1}: #{img[:format] || 'unknown'} format, #{img[:size_kb]}KB, key: #{img[:key]}"
    end
  else
    Rails.logger.info '[CustomPayload] Payload does not contain base64 images'
  end
end

def log_sanitized_payload(data)
  sanitized = LogSanitizer.sanitize_for_log(data, format: :detailed)
  Rails.logger.debug "[CustomPayload] Payload structure (sanitized): #{sanitized.to_json}"
end
```

#### SendMessageService (Standard Messages)

```ruby
# app/services/apple_messages_for_business/send_message_service.rb (lines 1069-1115)

def send_to_apple_gateway(payload, message_id, request_idr: false)
  # Sanitize event content before logging
  event_data = payload[:interactiveData]&.dig(:data, :event)
  if event_data
    sanitized_event = LogSanitizer.sanitize_for_log(event_data)
    Rails.logger.info "[AMB Send] event content: #{sanitized_event.inspect}"
  end

  # Sanitize list picker payload
  if payload[:interactiveData]&.dig(:data, :listPicker)
    list_picker = payload[:interactiveData][:data][:listPicker]
    sanitized_list_picker = LogSanitizer.sanitize_for_log(list_picker)
    Rails.logger.info "[AMB Send] 🔍 Final listPicker payload: #{sanitized_list_picker.to_json}"
  end

  # Send to Apple...
end
```

### Image Format Detection

LogSanitizer automatically detects image formats from base64 signatures:

| Format | Signature | Example |
|--------|-----------|---------|
| PNG | `iVBORw0KGgo` | `iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB...` |
| JPEG | `/9j/` | `/9j/4AAQSkZJRgABAQAAAQABAAD/2wBD...` |
| GIF | `R0lGOD` | `R0lGODlhAQABAIAAAP///////yH5BAEK...` |
| WebP | `UklGR` | `UklGRiQAAABXRUJQVlA4IBgAAAAwAQCd...` |
| BMP | `Qk` | `Qk0+AAAAAAAAADYAAAAoAAAA...` |
| TIFF | `SUkq` or `TU0A` | `SUkqAAgAAAAPAP4ABAABAAAAAAAAAAABAwA...` |
| ICO | `AAABA` | `AAABAAEAEBAAAAEAIABoBAAAFgAAA...` |

### Data URL Support

Handles data URLs with automatic format extraction:

```ruby
# Input
data_url = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBD..."

sanitized = LogSanitizer.sanitize_for_log({ image: data_url }, format: :detailed)

# Output
# { "image": "[BASE64 42.1KB | JPEG image | identifier: image | data URL]" }
```

---

## Rails Global Log Sanitizer

### Purpose

Global fallback sanitizer for ANY oversized log from any source. Particularly effective for high-frequency Sidekiq jobs.

### Location

**Module**: `RailsLogSanitizer::SanitizingLoggerProxy`
**File**: `config/initializers/rails_log_sanitizer.rb`

### How It Works

Wraps `Rails.logger` with a proxy that intercepts all logging methods:

```
Application Code
     ↓
 Rails.logger.info(message)
     ↓
SanitizingLoggerProxy (Tier 2)
     ↓
  sanitize_if_needed(message)
     ↓
  Original Logger
     ↓
 log/development.log
```

### Features

- ✅ Sanitizes high-frequency Sidekiq jobs: `ActionCableBroadcastJob`, `EventDispatcherJob`
- ✅ Truncates ANY log > 500 characters
- ✅ Works for all log levels (debug, info, warn, error, fatal)
- ✅ Preserves job metadata (class, queue, jid)
- ✅ Properly routes Sidekiq logs (fixes $stdout bypass)

### Configuration

```ruby
# config/initializers/rails_log_sanitizer.rb

HIGH_FREQUENCY_JOB_PATTERN = /(Enqueued|Performing).*(ActionCableBroadcastJob|EventDispatcherJob)/
MAX_LOG_LINE_SIZE = 500
```

### Results

**Before** (300KB+ per line):
```
Enqueued ActionCableBroadcastJob to Sidekiq(critical) with arguments:
["channel_id", "message.updated", {"id"=>123, "content_attributes"=>{"images"=>[{"data"=>"aXaZ...300KB of base64..."}]}}]
```

**After** (~50 bytes):
```
Enqueued ActionCableBroadcastJob to Sidekiq(critical) with arguments: [SANITIZED]
```

**Size reduction: 99.98%** 🎉

---

## Usage Patterns

### Pattern 1: Standard Apple Messages Service

Use compact format for info logs, detailed for debug:

```ruby
class SendListPickerService < SendMessageService
  def build_list_picker_data
    data = {
      sections: transform_sections(sections),
      images: transform_images(images)
    }

    # Info level: compact (production-friendly)
    sanitized = LogSanitizer.sanitize_for_log(data, format: :compact)
    Rails.logger.info "[ListPicker] Final data: #{sanitized.to_json}"

    # Debug level: detailed (development debugging)
    if Rails.env.development?
      detailed = LogSanitizer.sanitize_for_log(data, format: :detailed)
      Rails.logger.debug "[ListPicker] Detailed structure: #{detailed.to_json}"
    end

    data
  end
end
```

### Pattern 2: Custom Payload Service with Analysis

Analyze first, then log sanitized version:

```ruby
class SendCustomPayloadService < SendMessageService
  def build_interactive_data
    custom_data = parse_custom_payload(custom_payload_json)

    # Step 1: Analyze payload (reports image count and sizes)
    log_payload_analysis(custom_data)

    # Step 2: Log sanitized payload for debugging
    log_sanitized_payload(custom_data)

    custom_data
  end

  private

  def log_payload_analysis(data)
    return unless LogSanitizer.contains_base64?(data)

    summary = LogSanitizer.base64_summary(data)
    Rails.logger.info "[CustomPayload] Contains #{summary[:count]} image(s), #{summary[:total_kb]}KB total"

    # Log individual image details at debug level
    summary[:images].each_with_index do |img, idx|
      Rails.logger.debug "[CustomPayload]   Image #{idx + 1}: #{img[:format]}, #{img[:size_kb]}KB"
    end
  end

  def log_sanitized_payload(data)
    sanitized = LogSanitizer.sanitize_for_log(data, format: :detailed)
    Rails.logger.debug "[CustomPayload] Structure: #{sanitized.to_json}"
  end
end
```

### Pattern 3: Conditional Sanitization

Only sanitize when base64 is detected:

```ruby
def log_message_data(data)
  if LogSanitizer.contains_base64?(data)
    # Has images - sanitize for compact logs
    sanitized = LogSanitizer.sanitize_for_log(data, format: :compact)
    Rails.logger.info "[Message] Data: #{sanitized.to_json}"
  else
    # No images - log as-is
    Rails.logger.info "[Message] Data: #{data.to_json}"
  end
end
```

### Pattern 4: Preview for Error Logs

Use preview format in error logs to help debugging:

```ruby
def send_to_apple_gateway(payload)
  response = HTTParty.post(url, body: payload.to_json, headers: headers)

  unless response.success?
    # Use preview format to show first 20 chars of images
    sanitized = LogSanitizer.sanitize_for_log(payload, format: :preview, preview_length: 20)
    Rails.logger.error "[AMB Send] Failed to send: #{sanitized.to_json}"

    raise GatewayError
  end
end
```

---

## Testing

### Test Script

Run the comprehensive test suite:

```bash
rails runner test_log_sanitizer.rb
```

**Tests**:
1. ✅ Compact format - shows size only
2. ✅ Preview format - shows size + preview
3. ✅ Detailed format - shows size, format, identifier
4. ✅ contains_base64? helper - detection accuracy
5. ✅ base64_summary helper - statistics calculation

### Sample Test Output

```
================================================================================
1. COMPACT FORMAT (default) - shows just size
--------------------------------------------------------------------------------
Test: regular_image
{
  "identifier": "logo_png",
  "data": "[BASE64 9.38KB]"
}

Test: interactive_data
{
  "bid": "com.apple.messages.MSMessageExtensionBalloonPlugin:...",
  "data": {
    "version": "1.0",
    "listPicker": {
      "images": [
        {
          "identifier": "product_image",
          "data": "[BASE64 14.06KB]"
        }
      ]
    }
  }
}

================================================================================
4. CONTAINS_BASE64? HELPER - detect if data has base64
--------------------------------------------------------------------------------
regular_image: YES ✅
data_url_image: YES ✅
images_array: YES ✅
interactive_data: YES ✅
regular_data: NO ❌
```

### Manual Testing

Test in Rails console:

```ruby
# Test data with base64
payload = {
  'title' => 'Test',
  'image' => 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB' * 100
}

# Test compact
compact = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(payload)
puts compact.to_json

# Test preview
preview = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(payload, format: :preview)
puts preview.to_json

# Test detailed
detailed = AppleMessagesForBusiness::LogSanitizer.sanitize_for_log(payload, format: :detailed)
puts detailed.to_json

# Test detection
has_images = AppleMessagesForBusiness::LogSanitizer.contains_base64?(payload)
puts "Has images: #{has_images}"

# Test summary
summary = AppleMessagesForBusiness::LogSanitizer.base64_summary(payload)
puts "Count: #{summary[:count]}, Total: #{summary[:total_kb]}KB"
```

---

## Performance Impact

### Benchmarks

```ruby
# 100 iterations with 5 images (75KB total)
Benchmark.measure do
  100.times do
    LogSanitizer.sanitize_for_log(large_payload)
  end
end

# Results:
# Compact:  ~150ms (1.5ms per call)
# Preview:  ~180ms (1.8ms per call)
# Detailed: ~200ms (2.0ms per call)
```

### Impact Assessment

- ✅ **Negligible overhead**: <2ms per sanitization
- ✅ **Massive savings**: Prevents 99% log bloat (300KB → 50 bytes)
- ✅ **Production-safe**: Designed for high-frequency logging
- ✅ **Deep copy**: Non-destructive (doesn't mutate original data)

### Memory Usage

- Deep copy created only for hashes/arrays being logged
- Original data structures unchanged
- Garbage collection handles sanitized copies
- No memory leaks observed in testing

---

## Troubleshooting

### Issue: Base64 Not Being Detected

**Symptoms**: Images still appearing in logs in full

**Checklist**:
1. ✅ Is string > 200 characters?
2. ✅ Does key contain "data", "image", or "base64"?
3. ✅ Does string match base64 pattern?
4. ✅ Does string start with image signature?

**Debug**:
```ruby
value = 'iVBORw0KGgo...'
key = 'data'

# Check detection
detected = AppleMessagesForBusiness::LogSanitizer.looks_like_base64?(value, key)
puts "Detected: #{detected}"

# Check format
format = AppleMessagesForBusiness::LogSanitizer.detect_image_format(value)
puts "Format: #{format || 'unknown'}"
```

**Solution**: If not detected, image might be:
- Too short (<200 chars)
- Not actually base64 (contains non-base64 characters)
- Using unexpected encoding

### Issue: Performance Degradation

**Symptoms**: Slow logging, high CPU usage

**Causes**:
1. Logging massive payloads (>1MB) multiple times per request
2. Using `:detailed` format in production (heavier processing)
3. Not checking `contains_base64?` before sanitizing

**Solutions**:
```ruby
# 1. Check before sanitizing
if LogSanitizer.contains_base64?(data)
  sanitized = LogSanitizer.sanitize_for_log(data)
  Rails.logger.info sanitized.to_json
else
  Rails.logger.info data.to_json  # Skip sanitization
end

# 2. Use compact in production
format = Rails.env.production? ? :compact : :detailed
sanitized = LogSanitizer.sanitize_for_log(data, format: format)

# 3. Log at debug level for heavy payloads
Rails.logger.debug { LogSanitizer.sanitize_for_log(data).to_json }
```

### Issue: Global Sanitizer Not Working for Sidekiq

**Symptoms**: Sidekiq jobs still logging full payloads

**Root Cause**: Initialization order - Sidekiq captured logger before wrapping

**Verification**:
```bash
tail -f log/development.log | grep -E "Sidekiq|RailsLogger"
```

Should see:
```
[RailsLogger] Log sanitizer installed - oversized logs will be truncated
[RailsLogger] Sidekiq logger updated to use wrapped logger
```

If missing, initialization order is wrong.

**Solution**: Check `config/initializers/rails_log_sanitizer.rb`:
```ruby
Rails.application.config.after_initialize do
  # Step 1: Wrap Rails.logger FIRST
  Rails.logger = SanitizingLoggerProxy.new(Rails.logger)

  # Step 2: THEN update Sidekiq to use wrapped logger
  if defined?(Sidekiq)
    Sidekiq.configure_server { |config| config.logger = Rails.logger }
    Sidekiq.configure_client { |config| config.logger = Rails.logger }
  end
end
```

### Issue: Data URLs Not Being Sanitized

**Symptoms**: `data:image/png;base64,...` appearing in logs

**Check Pattern**:
```ruby
value = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAA..."

# Should match
matches = value.match?(%r{\Adata:image/[a-z]+;base64,}i)
puts "Matches: #{matches}"  # Should be true
```

**Solution**: Verify regex pattern in `looks_like_base64?`:
```ruby
return true if value.match?(%r{\Adata:image/[a-z]+;base64,}i)
```

---

## Files Reference

### Core Files

1. **Apple Messages LogSanitizer**:
   - `app/services/apple_messages_for_business/log_sanitizer.rb` - Main module
   - `app/services/apple_messages_for_business/send_custom_payload_service.rb` - Usage example
   - `app/services/apple_messages_for_business/send_message_service.rb` - Integration

2. **Rails Global Log Sanitizer**:
   - `config/initializers/rails_log_sanitizer.rb` - Wrapper and Sidekiq config

3. **Testing**:
   - `test_log_sanitizer.rb` - Comprehensive test suite (project root)

### Documentation

- `docs/apple-messages/LOG_SANITIZATION_COMPLETE_GUIDE.md` - This file
- `docs/log-sanitization-unified-solution.md` - Rails global sanitizer guide
- `docs/apple-messages/CUSTOM_PAYLOAD_FEATURE_PLAN.md` - Custom payload feature (references logging)

---

## Summary

### Two-Tier System Benefits

1. **Tier 1 (Apple Messages LogSanitizer)**:
   - ✅ Intelligent detection (format, size, identifier)
   - ✅ Flexible output formats
   - ✅ Preserves debugging context
   - ✅ Proactive sanitization at source

2. **Tier 2 (Rails Global Sanitizer)**:
   - ✅ Catches anything that slipped through
   - ✅ Protects against ANY oversized logs
   - ✅ Fixes Sidekiq $stdout bypass
   - ✅ Fallback safety net

### Results

- **Log file size**: 99% reduction (300KB/line → 50 bytes/line)
- **Debugging clarity**: Preserved with metadata
- **Performance**: <2ms overhead per sanitization
- **Production-ready**: Safe for high-frequency logging

---

**Document Version**: 1.0
**Last Review**: November 24, 2025
**Next Review**: After custom payload feature deployment
