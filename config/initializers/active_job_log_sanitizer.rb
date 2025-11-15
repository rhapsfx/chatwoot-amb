# frozen_string_literal: true

# Suppress verbose job argument logging by wrapping ALL Rails.logger methods

module RailsLoggerJobSuppressor
  def suppress_if_needed(message)
    return message unless message.is_a?(String)

    # Filter out "nil" lines completely (from puts statements)
    return nil if message.strip == 'nil'

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
      if block_given?
        super(suppress_if_needed(block.call))
      else
        super(suppress_if_needed(message))
      end
    end
  end

  # Override add (the underlying method all others call)
  def add(severity, message = nil, progname = nil)
    if block_given?
      super(severity, suppress_if_needed(yield), progname)
    else
      super(severity, suppress_if_needed(message), progname)
    end
  end

  # Override << method
  def <<(msg)
    super(suppress_if_needed(msg))
  end
end

Rails.application.config.after_initialize do
  Rails.logger.singleton_class.prepend(RailsLoggerJobSuppressor)
  Rails.logger.info '[RailsLogger] Job argument suppression active for ActionCableBroadcastJob and EventDispatcherJob'
end
