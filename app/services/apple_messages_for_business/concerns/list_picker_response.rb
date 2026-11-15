# frozen_string_literal: true

# Helpers for reading list picker responses.
#
# When a customer replies to a list picker, Apple rebuilds its sections: the
# section with the lowest `order` (0) holds the items the customer selected and
# the remaining sections hold the rest. Section titles such as "You Selected" or
# "Other" are localized by the device, so they must not be used to find the
# selection.
#
# https://register.apple.com/resources/messages/msp-rest-api/type-interactive#list-picker-message
module AppleMessagesForBusiness::Concerns::ListPickerResponse
  # Section holding the customer's selection (lowest `order`, first section when
  # the key is absent).
  def selected_list_picker_section(list_picker)
    sections = Array(list_picker && list_picker['sections'])
    sections.min_by { |section| section['order'].to_i }
  end

  # Items the customer selected in that section.
  def selected_list_picker_items(list_picker)
    Array(selected_list_picker_section(list_picker)&.dig('items'))
  end

  # Identifier of the first selected item, as returned by Apple (already the
  # identifier of the selected item, not a page identifier).
  def selected_list_picker_identifier(list_picker)
    value = selected_list_picker_items(list_picker).first&.dig('identifier')
    value.presence&.to_s
  end
end
