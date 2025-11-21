# Reduce Vite logging verbosity in development.log
# Vite logs are still visible in the Vite dev server output,
# but won't clutter the Rails logs

if Rails.env.development?
  # Monkey-patch ViteRuby logger to filter out verbose logs
  ViteRuby.instance.instance_eval do
    def logger
      @logger ||= begin
        base_logger = Rails.logger

        # Helper method to ensure UTF-8 encoding
        def ensure_utf8(message)
          return message unless message.is_a?(String)

          message.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
        end

        # Create a filtered logger that suppresses routine Vite messages
        filtered_logger = Object.new
        filtered_logger.define_singleton_method(:info) do |message|
          msg_str = message.to_s

          # Suppress standalone "vite" lines and routine messages
          return if msg_str.strip == 'vite'
          return if msg_str.include?('client connected')
          return if msg_str.include?('page reload')
          return if msg_str.include?('hmr update')

          # Suppress Vue compiler warnings about ::v-deep deprecation
          return if msg_str.include?('[@vue/compiler-sfc]') && msg_str.include?('::v-deep usage as a combinator has been deprecated')

          # Ensure UTF-8 encoding before logging
          utf8_message = ensure_utf8(msg_str)
          base_logger.info(utf8_message)
        end

        # Pass through other log levels with UTF-8 encoding
        [:debug, :warn, :error, :fatal].each do |level|
          filtered_logger.define_singleton_method(level) do |message|
            msg_str = message.to_s

            # Suppress Vue compiler warnings about ::v-deep deprecation
            return if msg_str.include?('[@vue/compiler-sfc]') && msg_str.include?('::v-deep usage as a combinator has been deprecated')

            utf8_message = ensure_utf8(msg_str)
            base_logger.send(level, utf8_message)
          end
        end

        filtered_logger
      end
    end
  end
end
