# frozen_string_literal: true

class AppleMessagesForBusiness::FormParserService
  def initialize(form_response_data)
    @form_data = form_response_data.dig('form_response', 'selections') || []
  end

  def extract_customer_name
    find_field_value(['full name', 'name', 'customer name'])
  end

  def extract_stage_name
    find_field_value(['stage name', 'artist name'])
  end

  def extract_address
    address_fields = {}

    field_patterns = {
      street: ['street', 'address', 'addr', 'line 1', 'address line'],
      city: %w[city town],
      state: %w[state province region],
      zip: ['zip', 'postal', 'postcode', 'zip code', 'postal code'],
      country: ['country']
    }

    @form_data.each do |section|
      title = section['title']&.downcase || ''
      value = section.dig('items', 0, 'value')

      next unless value.present?

      field_patterns.each do |field_type, patterns|
        if patterns.any? { |pattern| title.include?(pattern) }
          address_fields[field_type] = value
          break
        end
      end
    end

    address_fields.present? ? address_fields : nil
  end

  private

  def find_field_value(patterns)
    section = @form_data.find do |s|
      title = s['title']&.downcase || ''
      patterns.any? { |pattern| title.include?(pattern) }
    end

    section&.dig('items', 0, 'value')
  end
end
