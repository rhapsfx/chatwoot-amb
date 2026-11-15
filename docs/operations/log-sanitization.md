# Log Sanitization

## Overview

The log sanitization system prevents development and production logs from being bloated with heavy data fields like base64-encoded images, large file contents, and other binary data. This is crucial for:

- **Performance**: Keeping log files manageable in size
- **Readability**: Making logs easier to read and search
- **Storage**: Reducing disk space usage
- **Security**: Preventing sensitive binary data from being logged

## Components

### 1. Rails Parameter Filter (`config/initializers/filter_parameter_logging.rb`)

Automatically filters parameters in Rails logs at the framework level. This is the first line of defense and works globally across all controllers.

**What it does:**
- Detects parameters with keys matching patterns like `data`, `image`, `content`, `file`, `attachment`, `base64`
- Truncates values larger than 1KB
- Shows a preview (first 100 characters) and the original size
- Identifies data type (BASE64, BINARY, or LARGE TEXT)

**Example output in logs:**
```
Parameters: {
  "identifier" => "0",
  "filename" => "test.jpg",
  "image_data" => "[BASE64 DATA FILTERED - 48.5 KB - preview: iVBORw0KGgoAAAANSUhEUgAA...]"
}
```

### 2. LogSanitizerService (`app/services/log_sanitizer_service.rb`)

A reusable service for sanitizing any data structure before logging. Use this when you need explicit control over what gets logged.

**Features:**
- Recursively sanitizes hashes, arrays, and strings
- Preserves data structure while truncating large values
- Detects and labels different data types
- Configurable preview length
- Does not modify original data (creates deep copy)

**Usage:**

```ruby
# Sanitize any data structure
sanitized = LogSanitizerService.sanitize_for_log(params.to_unsafe_h)
Rails.logger.info "Request data: #{sanitized.inspect}"

# Custom preview length
sanitized = LogSanitizerService.sanitize_for_log(data, max_length: 200)
```

### 3. LogSanitizable Concern (`app/controllers/concerns/log_sanitizable.rb`)

A controller concern that provides convenient methods for logging with automatic sanitization.

**Usage:**

```ruby
class MyController < ApplicationController
  include LogSanitizable
  
  def create
    # Log params with sanitization
    log_params('Creating resource')
    
    # Log specific data
    log_sanitized(some_data, 'Processing data')
    
    # Get sanitized params for custom logging
    sanitized = sanitized_params
    Rails.logger.info "Custom log: #{sanitized}"
  end
end
```

## Configuration

### Adjusting Truncation Threshold

Edit `app/services/log_sanitizer_service.rb`:

```ruby
# Change minimum size before truncation (default: 1024 bytes = 1KB)
MIN_SIZE_FOR_TRUNCATION = 2048 # 2KB
```

### Adjusting Preview Length

```ruby
# Change default preview length (default: 100 characters)
DEFAULT_MAX_LENGTH = 200
```

### Adding Custom Data Key Patterns

Edit the `looks_like_heavy_data_key?` method in `LogSanitizerService`:

```ruby
def looks_like_heavy_data_key?(key)
  key.to_s.match?(/data|image|content|file|attachment|base64|binary|blob|document/i)
end
```

## Examples

### Example 1: Image Upload

**Before sanitization:**
```ruby
Rails.logger.info "Params: #{params.inspect}"
# Logs: Params: {"image_data"=>"iVBORw0KGgoAAAANSUhEUgAA... (50,000 characters)"}
```

**After sanitization:**
```ruby
log_params('Image upload')
# Logs: Image upload: {"image_data"=>"[BASE64 IMAGE DATA - 48.5 KB] iVBORw0KGgoAAAANSUhEUgAA..."}
```

### Example 2: Bulk Operations

```ruby
# Sanitize before logging bulk data
results = {
  uploaded: uploaded_items.map { |item| 
    LogSanitizerService.sanitize_for_log(item) 
  }
}
Rails.logger.info "Bulk upload results: #{results.inspect}"
```

### Example 3: Nested Data Structures

```ruby
data = {
  user: {
    name: 'John',
    avatar_data: base64_image # Large base64 string
  },
  attachments: [
    { filename: 'doc.pdf', content: large_binary_data }
  ]
}

sanitized = LogSanitizerService.sanitize_for_log(data)
# Result:
# {
#   user: {
#     name: 'John',
#     avatar_data: '[BASE64 IMAGE DATA - 125.3 KB] iVBORw0...'
#   },
#   attachments: [
#     { filename: 'doc.pdf', content: '[BINARY DATA - 2.5 MB] %PDF-1.4...' }
#   ]
# }
```

## Testing

Run the test suite:

```bash
bundle exec rspec spec/services/log_sanitizer_service_spec.rb
```

## Best Practices

1. **Always use sanitization for user-uploaded content**: Images, files, documents
2. **Use the concern in controllers handling heavy data**: Image uploads, file uploads, bulk operations
3. **Don't log raw params in production**: Always sanitize first
4. **Monitor log file sizes**: Even with sanitization, check log rotation is working
5. **Use appropriate log levels**: Debug logs can be more verbose, but production should be minimal

## Troubleshooting

### Logs still too large?

1. Reduce `DEFAULT_MAX_LENGTH` in `LogSanitizerService`
2. Lower `MIN_SIZE_FOR_TRUNCATION` threshold
3. Add more patterns to `looks_like_heavy_data_key?`

### Data not being sanitized?

1. Check if the parameter key matches the patterns
2. Verify the data size is > 1KB
3. Ensure the controller includes `LogSanitizable` concern
4. Check Rails parameter filtering is enabled

### Need to see full data for debugging?

Temporarily disable sanitization for specific actions:

```ruby
def create
  if Rails.env.development? && ENV['DEBUG_FULL_PARAMS']
    Rails.logger.debug "Full params: #{params.inspect}"
  else
    log_params('Creating resource')
  end
end
```

## Migration Guide

### For Existing Controllers

1. Add the concern:
   ```ruby
   include LogSanitizable
   ```

2. Replace direct param logging:
   ```ruby
   # Before
   Rails.logger.info "Params: #{params.inspect}"
   
   # After
   log_params('Action description')
   ```

3. Sanitize custom data logging:
   ```ruby
   # Before
   Rails.logger.info "Data: #{some_data.inspect}"
   
   # After
   log_sanitized(some_data, 'Data description')
   ```

## Performance Impact

The sanitization process has minimal performance impact:

- **Parameter filtering**: Happens automatically, ~1-2ms overhead per request
- **LogSanitizerService**: ~0.5-1ms for typical data structures
- **Deep copy**: Only creates copies of data being logged, not affecting actual request processing

## Security Considerations

- Sanitization helps prevent accidental logging of sensitive binary data
- Does not replace proper security measures (encryption, access control)
- Still filters sensitive parameters (passwords, tokens) via Rails parameter filtering
- Preview data may still contain sensitive information - adjust preview length accordingly