# frozen_string_literal: true

# Suppress verbose job argument logging by wrapping ALL Rails.logger methods

# Wrapper for the log device (IO) to filter out "nil" lines at write level
class NilFilteringLogDevice
  def initialize(log_device)
    @log_device = log_device
  end

  def write(message)
    # Filter out standalone "nil" lines completely
    return if message.is_a?(String) && (message.strip == 'nil' || message == "nil\n")
    
    @log_device.write(message)
  end

  def close
    @log_device.close
  end

  def reopen(logdev = nil)
    @log_device.reopen(logdev) if @log_device.respond_to?(:reopen)
  end

  # Forward any other methods to the underlying device
  def method_missing(method, *args, &block)
    @log_device.send(method, *args, &block)
  end

  def respond_to_missing?(method, include_private = false)
    @log_device.respond_to?(method, include_private) || super
  end
end

module RailsLoggerJobSuppressor
  def suppress_if_needed(message)
    return message unless message.is_a?(String)

    # Filter out "nil" lines completely (from puts statements or return values)
    # Check for standalone "nil" or "nil" with whitespace
    return '' if message.strip == 'nil' || message == 'nil'

    # Check if this is a verbose job log
    if (message.include?('ActionCableBroadcastJob') || message.include?('EventDispatcherJob')) &&
       message.include?('with arguments:')
      # Truncate everything after "with arguments:"
      return message.split('with arguments:').first + 'with arguments: [SUPPRESSED]'
    end

    # Check if this is ContentAttributeValidator with base64 data
    if message.include?('ContentAttributeValidator') && message.include?('"data"=>')
      # Truncate base64 data in the message
      message = message.gsub(/"data"=>"[^"]{100,}"/, '"data"=>"[BASE64 TRUNCATED]"')
    end

    message
  end

  # Override all log level methods
  %w[debug info warn error fatal unknown].each do |level|
    define_method(level) do |message = nil, &block|
      msg = block_given? ? block.call : message
      suppressed = suppress_if_needed(msg)
      # Skip logging entirely if message was filtered out
      return if suppressed == ''
      super(suppressed)
    end
  end

  # Override add (the underlying method all others call)
  def add(severity, message = nil, progname = nil)
    msg = block_given? ? yield : message
    suppressed = suppress_if_needed(msg)
    # Skip logging entirely if message was filtered out
    return if suppressed == ''
    super(severity, suppressed, progname)
  end

  # Override << method
  def <<(msg)
    suppressed = suppress_if_needed(msg)
    # Skip logging entirely if message was filtered out
    return if suppressed == ''
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
