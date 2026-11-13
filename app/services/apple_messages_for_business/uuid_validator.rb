module AppleMessagesForBusiness::UuidValidator
  UUID_REGEX = /\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/

  module_function

  def valid?(value)
    value.is_a?(String) && value.match?(UUID_REGEX)
  end
end
