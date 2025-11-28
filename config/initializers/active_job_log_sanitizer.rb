# frozen_string_literal: true

# Suppress verbose job argument logging by wrapping ALL Rails.logger methods

# Wrapper for the log device (IO) to filter out "nil" lines at write level
class NilFilteringLogDevice
  def initialize(log_device)
    @log_device = log_device
  end

  def write(message)
    return unless message.is_a?(String)

    # Filter out standalone "nil" lines completely
    return if message.strip == 'nil' || message == "nil\n"

    # Filter out Vue compiler warnings about ::v-deep deprecation
    # Check for the warning text with or without ANSI color codes
    return if message.include?('::v-deep usage as a combinator has been deprecated')

    # Also filter lines that only contain ANSI color codes and whitespace
    # (leftover formatting from filtered messages)
    clean_msg = message.gsub(/\e\[[0-9;]*m/, '').strip
    return if clean_msg.empty?

    @log_device.write(message)
  end

  def close
    @log_device.close
  end

  def reopen(logdev = nil)
    @log_device.reopen(logdev) if @log_device.respond_to?(:reopen)
  end

  # Forward any other methods to the underlying device
  def method_missing(method, *, &)
    @log_device.send(method, *, &)
  end

  def respond_to_missing?(method, include_private = false)
    @log_device.respond_to?(method, include_private) || super
  end
end

module RailsLoggerJobSuppressor
  def suppress_if_needed(message)
    # CRITICAL: Filter out nil values BEFORE they get formatted
    # This prevents "nil" from appearing in logs
    return nil if message.nil?

    return message unless message.is_a?(String)

    # Ensure UTF-8 encoding to prevent mojibake (garbled text)
    # This fixes emoji and special characters in log messages
    message = message.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')

    # Filter out "nil" lines completely (from puts statements or return values)
    # Check for standalone "nil" or "nil" with whitespace
    return nil if message.strip == 'nil' || message == 'nil'

    # Filter out Vue compiler warnings about ::v-deep deprecation
    # These are repetitive warnings that clutter the logs
    if (message.include?('[@vue/compiler-sfc]') || message.include?('@vue/compiler-sfc')) && message.include?('::v-deep usage as a combinator has been deprecated')
      return nil
    end

    # Check if this is a verbose job log
    if (message.include?('ActionCableBroadcastJob') || message.include?('EventDispatcherJob')) &&
       message.include?('with arguments:')
      # Truncate everything after "with arguments:"
      return message.split('with arguments:').first + 'with arguments: [SUPPRESSED]'
    end

    # Sanitize base64 data in various contexts
    # Pattern 1: ContentAttributeValidator with base64 data
    if message.include?('ContentAttributeValidator') && message.include?('"data"=>')
      message = message.gsub(/"data"=>"[^"]{100,}"/, '"data"=>"[BASE64 TRUNCATED]"')
    end

    # Pattern 2: Parameters with base64 data (more aggressive)
    # This handles cases like: "data"=>"[BASE64 DATA FILTERED - 499.32 KB - preview: iVBORw0K...]"
    if message.include?('Parameters:') || message.include?('"data"=>') || message.include?('Custom Apple Messages payload')
      # First, handle already filtered base64 with preview - clean it up
      # This must come BEFORE the general base64 truncation to preserve the marker
      message = message.gsub(/\[BASE64 DATA FILTERED - [\d.]+ [KMG]B - preview: [^\]]+\]/, '[BASE64 DATA FILTERED]')
      message = message.gsub(/("data"=>")\[BASE64 DATA FILTERED[^\]]+\]"/, '\1[BASE64 DATA FILTERED]"')

      # Then remove long base64 strings (anything that looks like base64 data > 100 chars)
      # Skip if already marked as [BASE64 DATA FILTERED]
      message = message.gsub(/("data"=>"(?!\[BASE64 DATA FILTERED\])[^"]{100,}")/, '"data"=>"[BASE64 TRUNCATED]"')

      # Also handle the preview field with base64
      message = message.gsub(%r{("preview"=>"data:image/[^;]+;base64,[^"]{50,}")}, '"preview"=>"[BASE64 IMAGE]"')

      # For Custom Apple Messages payload specifically, aggressively filter content_attributes
      if message.include?('Custom Apple Messages payload')
        # Replace entire content_attributes hash with summary when it's too large
        message = message.gsub(/"content_attributes"=>\{[^}]{500,}\}/, '"content_attributes"=>{...TRUNCATED...}')
      end
    end

    message
  end

  # Override all log level methods
  %w[debug info warn error fatal unknown].each do |level|
    define_method(level) do |message = nil, &block|
      msg = block_given? ? block.call : message
      suppressed = suppress_if_needed(msg)
      # Skip logging entirely if message was filtered out (nil or empty)
      return if suppressed.nil?

      super(suppressed)
    end
  end

  # Override add (the underlying method all others call)
  def add(severity, message = nil, progname = nil)
    msg = block_given? ? yield : message
    suppressed = suppress_if_needed(msg)
    # Skip logging entirely if message was filtered out (nil or empty)
    return if suppressed.nil?

    super(severity, suppressed, progname)
  end

  # Override << method
  def <<(msg)
    suppressed = suppress_if_needed(msg)
    # Skip logging entirely if message was filtered out (nil or empty)
    return if suppressed.nil?

    super(suppressed)
  end
end

Rails.application.config.after_initialize do
  # Wrap the logger's log device to filter at IO level
  if Rails.logger.instance_variable_defined?(:@logdev) && Rails.logger.instance_variable_get(:@logdev)
    logdev = Rails.logger.instance_variable_get(:@logdev)
    if logdev.instance_variable_defined?(:@dev) && logdev.instance_variable_get(:@dev)
      original_dev = logdev.instance_variable_get(:@dev)
      wrapped_dev = NilFilteringLogDevice.new(original_dev)
      logdev.instance_variable_set(:@dev, wrapped_dev)
    end
  end

  # Also wrap the logger methods for additional filtering
  Rails.logger.singleton_class.prepend(RailsLoggerJobSuppressor)
  Rails.logger.info '[RailsLogger] Job argument suppression active for ActionCableBroadcastJob and EventDispatcherJob'
end
