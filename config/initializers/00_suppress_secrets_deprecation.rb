# frozen_string_literal: true

# Suppress Rails.application.secrets deprecation warning
# Rails 7.1 still checks for secrets during initialization even if not used
# This app uses environment variables and credentials instead
# This initializer must load before other initializers (hence 00_ prefix)

Rails.application.config.before_initialize do
  # Ensure secret_key_base is set from environment variable
  # This prevents Rails from looking for secrets.yml
  Rails.application.credentials.secret_key_base = ENV['SECRET_KEY_BASE'] if ENV['SECRET_KEY_BASE'].present?
end
